require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class MenuSection::DraftTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "sections have their own presentation and ordered shared product references" do
    menu = create_catalogue_menu
    product = create_catalogue_product
    first = add_menu_section(menu, product_ids: [ product.id ])
    second = add_menu_section(menu, name: "Sharing", product_ids: [ product.id ])
    assert_equal menu, first.parent
    assert_equal menu.bucket, first.bucket
    assert_equal [ first.id, second.id ], menu.reload.recordable.section_order
    assert_equal [ "Sharing" ], Menu::Structure.new(menu).other_sections(product, except: first)
    refute product.catalogue_published?, "Unpublished products may be selected in drafts"
    assert_equal Current.person, first.events.sole.person
    assert_includes menu.timeline_events, first.events.sole
  end

  test "duplicate foreign and newly archived products are rejected without partial writes" do
    menu = create_catalogue_menu
    product = create_catalogue_product
    section = add_menu_section(menu, product_ids: [ product.id ])
    product.archive_content!(revision: product.draft_revision)
    retained = MenuSection::Draft.for(menu.reload, section)
    retained.name = "Updated"
    assert retained.save
    foreign = create_catalogue_product(bucket: Bucket.create!(name: "Other"))
    [ [ product.id ], [ foreign.id ], [ foreign.id, foreign.id ] ].each do |ids|
      invalid = MenuSection::Draft.new(menu: menu.reload, revision: menu.draft_revision, name: "Invalid", product_ids: ids)
      assert_no_difference([ "MenuSection.count", "Recording.count", "Event.count" ]) { refute invalid.save }
      assert invalid.errors[:product_ids].any?
    end
    duplicate = MenuSection::Draft.for(menu.reload, section.reload)
    duplicate.product_ids = [ product.id, product.id ]
    refute duplicate.save
  end

  test "editing cannot target another menu or overwrite a newer section change" do
    menu = create_catalogue_menu
    section = add_menu_section(menu)
    other = create_catalogue_menu
    wrong = MenuSection::Draft.for(other, section)
    refute wrong.save
    stale = MenuSection::Draft.for(menu.reload, section)
    latest = MenuSection::Draft.for(menu, section)
    latest.name = "Latest"
    assert latest.save
    assert_raises(Recording::CatalogueEditing::StaleDraft) { stale.save }
    assert_equal "Latest", section.reload.recordable.name
  end

  test "failed parent update rolls back section creation and permits retry" do
    menu = create_catalogue_menu
    draft = MenuSection::Draft.new(menu: menu, revision: menu.draft_revision, name: "Starters")
    invalid = Menu.new
    failure = ->(*) { raise ActiveRecord::RecordInvalid.new(invalid) }
    assert_no_difference [ "MenuSection.count", "Recording.count", "Event.count" ] do
      with_class_method_replacement(Menu, :new, failure) { refute draft.save }
    end
    assert_nil draft.recording
    assert draft.save
    assert_equal [ draft.recording.id ], menu.reload.recordable.section_order
  end

  test "section image changes preserve previous versions and product order" do
    menu = create_catalogue_menu
    product = create_catalogue_product
    section = add_menu_section(menu, product_ids: [ product.id ], image: Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png"))
    previous = section.recordable
    draft = MenuSection::Draft.for(menu.reload, section)
    draft.name = "Updated"
    assert draft.save
    assert_equal previous.image.blob, section.reload.recordable.image.blob
    assert_equal [ product.id ], section.recordable.product_ids
    draft = MenuSection::Draft.for(menu.reload, section)
    draft.remove_image = "1"
    assert draft.save
    refute section.reload.recordable.image.attached?
    assert previous.reload.image.attached?
  end
end
