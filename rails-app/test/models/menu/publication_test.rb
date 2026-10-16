require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Menu::PublicationTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  setup do
    @product = create_catalogue_product
    @product_publication = Product::Publication.new(@product)
    @product_publication.publish!(token: @product_publication.review_token)
    @menu = create_catalogue_menu
    @section = add_menu_section(@menu, product_ids: [ @product.id ])
    @publication = Menu::Publication.new(@menu.reload)
  end

  test "publication snapshots menu presentation and placements while products retain independent versions" do
    empty = add_menu_section(@menu, name: "Empty draft")
    @menu.reload
    @publication.publish!(token: @publication.review_token)
    snapshot = @publication.release.snapshot
    assert_equal [ @section.id ], snapshot.content.fetch("sections").map { |section| section.fetch("id") }
    assert_equal [ @section.id, empty.id ], @menu.reload.recordable.section_order
    assert_equal [ @product.id ], snapshot.content.fetch("sections").sole.fetch("product_ids")
    refute @publication.changed?
    variant = @product.children.variants.sole
    edit = Product::VariantDraft.for(@product.reload, variant)
    edit.price = "9"
    assert edit.save
    refute @publication.changed?
    @product.reload
    @product_publication.publish!(token: @product_publication.review_token)
    assert_equal "9.0", Catalogue::PublishedProduct.new(@product).variants.sole.fetch("price")
    assert_equal snapshot, @publication.release.snapshot
    refute VariantAvailability.find_by!(recording: variant).available?
    event = @menu.events.where(action: "published").sole
    assert_equal Current.person, event.person
    assert_equal snapshot.id.to_s, event.details.find_by!(key: "snapshot_id").value
  end

  test "empty or unresolved menus cannot replace the live menu or publish products automatically" do
    @publication.publish!(token: @publication.review_token)
    candidate = create_catalogue_menu(name: "Lunch")
    other = Menu::Publication.new(candidate)
    assert_raises(Menu::Publication::Invalid) { other.publish!(token: other.review_token) }
    unpublished = create_catalogue_product(name: "Lemonade")
    add_menu_section(candidate, product_ids: [ unpublished.id ])
    candidate.reload
    assert_equal [ unpublished ], other.blocking_products.to_a
    assert_no_difference [ "Catalogue::Snapshot.count", "Catalogue::Release.count", "Event.count" ] do
      assert_raises(Menu::Publication::Invalid) { other.publish!(token: other.review_token) }
    end
    assert_equal @menu, Catalogue::Release.live_menu(Current.bucket).recording
    refute unpublished.catalogue_published?
  end

  test "replacing a live menu records both transitions and unpublishing leaves no live menu" do
    @publication.publish!(token: @publication.review_token)
    candidate = create_catalogue_menu(name: "Lunch")
    add_menu_section(candidate, product_ids: [ @product.id ])
    other = Menu::Publication.new(candidate.reload)
    other.publish!(token: other.review_token)
    refute @publication.published?
    assert other.published?
    assert_equal 1, Catalogue::Release.active.where(bucket: Current.bucket, kind: "Menu").count
    event = @menu.events.where(action: "unpublished").sole
    assert_equal candidate.id.to_s, event.details.find_by!(key: "replaced_by_menu_id").value
    other.unpublish!(token: other.review_token)
    assert_nil Catalogue::Release.live_menu(Current.bucket)
    assert other.previous_content
  end

  test "failed replacement rolls back both release states snapshots and transition events" do
    @publication.publish!(token: @publication.review_token)
    candidate = create_catalogue_menu(name: "Lunch")
    add_menu_section(candidate, product_ids: [ @product.id ])
    other = Menu::Publication.new(candidate.reload)
    invalid = Catalogue::Release.new
    failure = ->(**) { raise ActiveRecord::RecordInvalid.new(invalid) }
    assert_no_difference [ "Catalogue::Snapshot.count", "Catalogue::Release.count", "Event.count" ] do
      with_class_method_replacement(Catalogue::Release, :new, failure) do
        assert_raises(ActiveRecord::RecordInvalid) { other.publish!(token: other.review_token) }
      end
    end
    assert @publication.published?
    refute other.published?
  end

  test "confirmation becomes stale after draft dependency or live-menu changes" do
    token = @publication.review_token
    @product_publication.unpublish!(token: @product_publication.review_token)
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @publication.publish!(token: token) }
    @product_publication.publish!(token: @product_publication.review_token)
    token = @publication.review_token
    edit = MenuSection::Draft.for(@menu, @section)
    edit.name = "Updated section"
    assert edit.save
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @publication.publish!(token: token) }
    candidate = create_catalogue_menu(name: "Lunch")
    add_menu_section(candidate, product_ids: [ @product.id ])
    other = Menu::Publication.new(candidate.reload)
    token = @publication.review_token
    other.publish!(token: other.review_token)
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @publication.publish!(token: token) }
  end

  test "revert restores menu and section images and placements without changing product or publication state" do
    upload = -> { Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png") }
    edit = Menu::Draft.for(@menu)
    edit.image = upload.call
    assert edit.save
    section_edit = MenuSection::Draft.for(@menu.reload, @section)
    section_edit.image = upload.call
    assert section_edit.save
    @menu.reload
    @publication.publish!(token: @publication.review_token)
    menu_image = @menu.recordable.image.blob
    section_image = @section.reload.recordable.image.blob
    @publication.unpublish!(token: @publication.review_token)
    Menu::Structure.new(@menu).remove!(@section, revision: @menu.draft_revision)
    extra = add_menu_section(@menu, name: "New draft section")
    edit = Menu::Draft.for(@menu.reload)
    edit.name = "Changed"
    edit.remove_image = "1"
    assert edit.save
    @product.revise_content!(@product.recordable.attributes.except("id").merge("name" => "Independent edit"), revision: @product.draft_revision)
    @publication.revert!(token: @publication.review_token)
    assert_equal "Evening menu", @menu.reload.recordable.name
    assert_equal [ @section.id ], @menu.recordable.section_order
    assert_equal menu_image, @menu.recordable.image.blob
    assert_equal section_image, @section.reload.recordable.image.blob
    assert_equal [ @product.id ], @section.recordable.product_ids
    assert_equal "Independent edit", @product.reload.recordable.name
    refute @publication.published?
    refute @publication.changed?
    assert extra.reload.kept?
    assert extra.events.exists?
    assert @menu.events.exists?(action: "reverted")
  end

  test "menu revert preserves archived product references and never published or archived menus are rejected" do
    assert_raises(Menu::Publication::Invalid) { @publication.revert!(token: @publication.review_token) }
    @publication.publish!(token: @publication.review_token)
    @product.archive_content!(revision: @product.draft_revision)
    @publication.revert!(token: @publication.review_token)
    assert @product.reload.discarded?
    assert_equal [ "Wings" ], @publication.archived_references
    @menu.archive_content!(revision: @menu.draft_revision)
    assert_raises(Menu::Publication::Invalid) { @publication.publish!(token: @publication.review_token) }
    assert_raises(Menu::Publication::Invalid) { @publication.revert!(token: @publication.review_token) }
  end

  test "product cannot unpublish while any live placement remains even after draft removal" do
    another_section = add_menu_section(@menu, name: "Sharing", product_ids: [ @product.id ])
    @publication.publish!(token: @publication.review_token)
    [ @section, another_section ].each do |section|
      Menu::Structure.new(@menu).remove!(section, revision: @menu.draft_revision)
      assert_raises(Product::Publication::Invalid) { @product_publication.unpublish!(token: @product_publication.review_token) }
    end
    @publication.unpublish!(token: @publication.review_token)
    @product_publication.unpublish!(token: @product_publication.review_token)
    refute @product_publication.published?
  end
end
