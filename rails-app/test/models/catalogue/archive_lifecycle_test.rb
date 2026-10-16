require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Catalogue::ArchiveLifecycleTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  setup do
    @product = create_catalogue_product
    @variant = @product.children.variants.first
    @large = add_catalogue_variant(@product)
    publish_product
    @menu = create_catalogue_menu
    add_menu_section(@menu, product_ids: [ @product.id ])
    publication = Menu::Publication.new(@menu.reload)
    publication.publish!(token: publication.review_token)
    VariantAvailability.where(recording: [ @variant, @large ]).update_all(available: true)
  end

  test "archiving a product withdraws every variant and restoring preserves publications without resuming sales" do
    snapshots = Catalogue::Snapshot.order(:id).pluck(:id, :content)
    content = @product.reload.recordable
    @product.archive_content!(revision: @product.draft_revision)
    assert_empty live_sections
    assert @product.catalogue_published?
    refute VariantAvailability.where(recording: [ @variant, @large ], available: true).exists?
    assert @variant.reload.kept?
    [ @variant, @large ].each do |variant|
      event = variant.events.find_by!(action: "availability_changed")
      assert_equal Current.person, event.person
      assert_equal "Product archived", event.details.find_by!(key: "reason").value
    end
    @product.restore_content!(revision: @product.reload.draft_revision)
    assert_equal 2, live_sections.sole.fetch("products").sole.variants.size
    assert_equal content, @product.reload.recordable
    assert_equal snapshots, Catalogue::Snapshot.order(:id).pluck(:id, :content)
    refute VariantAvailability.where(recording: [ @variant, @large ], available: true).exists?
    assert_equal %w[discarded restored], @product.events.where(action: %w[discarded restored]).order(:id).pluck(:action)
  end

  test "archived variants hide products and empty sections then restore as sold out without republishing" do
    archive(@variant)
    assert_equal [ @large.id ], live_sections.sole.fetch("products").sole.variants.pluck("id")
    assert VariantAvailability.find_by!(recording: @large).available?
    archive(@large)
    assert_empty live_sections
    @variant.restore_content!(revision: @variant.reload.draft_revision)
    visible = live_sections.sole.fetch("products").sole
    assert_equal [ @variant.id ], visible.variants.pluck("id")
    assert_equal "Sold out", visible.availability_for(visible.variants.sole)
    assert @large.reload.discarded?
  end

  test "restoring a variant does not reveal an archived parent or a draft-only variant" do
    draft_variant = add_catalogue_variant(@product, name: "Draft only")
    archive(draft_variant)
    draft_variant.restore_content!(revision: draft_variant.reload.draft_revision)
    assert_equal [ @variant.id, @large.id ], live_sections.sole.fetch("products").sole.variants.pluck("id")
    archive(@variant)
    archive(@product)
    @variant.restore_content!(revision: @variant.reload.draft_revision)
    assert_empty live_sections
    @product.restore_content!(revision: @product.reload.draft_revision)
    assert_equal [ @variant.id, @large.id ], live_sections.sole.fetch("products").sole.variants.pluck("id")
  end

  test "menu archiving atomically unpublishes and restoration never replaces the new live menu" do
    snapshots = Catalogue::Snapshot.count
    archive(@menu)
    assert_nil Catalogue::Release.live_menu(Current.bucket)
    assert @menu.catalogue_previously_published?
    event = @menu.events.find_by!(action: "unpublished")
    assert_equal "Menu archived", event.details.find_by!(key: "reason").value
    assert_equal Current.person, event.person
    assert_equal snapshots, Catalogue::Snapshot.count
    other = create_catalogue_menu(name: "Lunch")
    add_menu_section(other, product_ids: [ @product.id ])
    publication = Menu::Publication.new(other.reload)
    publication.publish!(token: publication.review_token)
    @menu.restore_content!(revision: @menu.reload.draft_revision)
    refute @menu.catalogue_published?
    assert_equal other, Catalogue::Release.live_menu(Current.bucket).recording
    assert VariantAvailability.find_by!(recording: @variant).available?
  end

  test "a failed archive rolls back availability events and menu unpublication" do
    [ @product, @menu ].each do |recording|
      recording.reload
      recording.define_singleton_method(:discard!) { raise ActiveRecord::RecordInvalid.new(self) }
      assert_no_difference "Event.count" do
        assert_raises(ActiveRecord::RecordInvalid) { recording.archive_content!(revision: recording.draft_revision) }
      end
      assert recording.reload.kept?
    end
    assert VariantAvailability.find_by!(recording: @variant).available?
    assert VariantAvailability.find_by!(recording: @large).available?
    assert_equal @menu, Catalogue::Release.live_menu(Current.bucket).recording
  end

  test "stale archive and restore cannot change state or availability" do
    old_revision = @product.reload.draft_revision
    add_catalogue_variant(@product, name: "New")
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @product.archive_content!(revision: old_revision) }
    assert VariantAvailability.find_by!(recording: @variant).available?
    archive(@product)
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @product.restore_content!(revision: old_revision) }
    assert @product.reload.discarded?
  end

  test "archiving a variant invalidates reviewed product publication and snapshot visibility follows latest publication" do
    publication = Product::Publication.new(@product.reload)
    token = publication.review_token
    archive(@variant)
    assert_raises(Recording::CatalogueEditing::StaleDraft) { publication.publish!(token: token) }
    publish_product
    @variant.restore_content!(revision: @variant.reload.draft_revision)
    assert_equal [ @large.id ], live_sections.sole.fetch("products").sole.variants.pluck("id")
    publish_product
    assert_equal [ @variant.id, @large.id ], live_sections.sole.fetch("products").sole.variants.pluck("id")
  end

  private

  def archive(recording)
    recording.archive_content!(revision: recording.reload.draft_revision)
  end

  def publish_product
    publication = Product::Publication.new(@product.reload)
    publication.publish!(token: publication.review_token)
  end

  def live_sections = Catalogue::LiveMenu.new(Current.bucket).sections
end
