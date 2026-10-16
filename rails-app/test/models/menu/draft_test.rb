require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Menu::DraftTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "empty menu drafts are valid owned and tracked" do
    menu = create_catalogue_menu
    assert menu.menu?
    assert_equal Current.bucket, menu.bucket
    assert_equal Current.person, menu.events.sole.person
    assert_empty Menu::Draft.for(menu).sections
    refute menu.catalogue_published?
  end

  test "edits preserve immutable images and sections and support explicit image removal" do
    menu = create_catalogue_menu(image: Rack::Test::UploadedFile.new(Rails.root.join("public/icon.png"), "image/png"))
    original = menu.recordable
    section = add_menu_section(menu)
    draft = Menu::Draft.for(menu.reload)
    draft.name = "Lunch"
    assert draft.save
    assert_equal "Evening menu", original.reload.name
    assert_equal original.image.blob, menu.reload.recordable.image.blob
    assert_equal [ section.id ], menu.recordable.section_order
    draft = Menu::Draft.for(menu)
    draft.remove_image = "1"
    assert draft.save
    refute menu.reload.recordable.image.attached?
    assert original.image.attached?
  end

  test "invalid cross-bucket stale and archived edits do not change menu content" do
    invalid = Menu::Draft.new(bucket: Current.bucket, name: "")
    assert_no_difference([ "Menu.count", "Recording.count", "Event.count" ]) { refute invalid.save }
    menu = create_catalogue_menu
    draft = Menu::Draft.for(menu)
    draft.bucket = Bucket.create!(name: "Other")
    refute draft.save
    draft = Menu::Draft.for(menu)
    add_menu_section(menu)
    assert_raises(Recording::CatalogueEditing::StaleDraft) { draft.save }
    menu.reload.archive_content!(revision: menu.draft_revision)
    assert_raises(Authorization::Denied) { Menu::Draft.for(menu.reload).save }
  end
end
