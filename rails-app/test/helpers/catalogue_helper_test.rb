require "test_helper"

class CatalogueHelperTest < ActionView::TestCase
  test "menu context preserves recorded names and scopes legacy references to the bucket" do
    menu = Current.bucket.recordings.create!(recordable: Menu.new(name: "Dinner"))
    other = Current.bucket.recordings.create!(recordable: Menu.new(name: "Lunch"))
    event = menu.events.create!(bucket: Current.bucket, subject: menu.recordable, action: "unpublished")
    event.details.create!(key: "replaced_by_menu_id", value: other.id.to_s)
    assert_equal "Replaced by Lunch.", catalogue_menu_transition(event)
    event.details.create!(key: "replaced_by_menu_name", value: "Published lunch")
    other.update!(recordable: Menu.new(name: "Later rename"))
    assert_equal "Replaced by Published lunch.", catalogue_menu_transition(event.reload)

    foreign = Bucket.create!(name: "Other").recordings.create!(recordable: Menu.new(name: "Private"))
    invalid = menu.events.create!(bucket: Current.bucket, subject: menu.recordable, action: "published")
    invalid.details.create!(key: "replaced_menu_id", value: foreign.id.to_s)
    invalid.details.create!(key: "replaced_menu_name", value: "Private")
    assert_equal "Replaced an unavailable menu.", catalogue_menu_transition(invalid)
  end

  test "menu archival shows its reason and republication does not claim self replacement" do
    menu = Current.bucket.recordings.create!(recordable: Menu.new(name: "Dinner"))
    event = menu.events.create!(bucket: Current.bucket, subject: menu.recordable, action: "unpublished")
    event.details.create!(key: "reason", value: "Menu archived")
    assert_equal "Menu archived", catalogue_menu_transition(event)
    published = menu.events.create!(bucket: Current.bucket, subject: menu.recordable, action: "published")
    published.details.create!(key: "replaced_menu_id", value: menu.id.to_s)
    assert_nil catalogue_menu_transition(published)
  end
end
