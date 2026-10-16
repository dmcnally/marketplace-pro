require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class CategoryTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "requires a name and allows an absent description" do
    refute Category.new(name: " ").valid?
    assert Category.new(name: "Starters").valid?
  end

  test "persisted content cannot be changed or deleted" do
    assert_immutable_content Category.create!(name: "Starters")
  end

  test "recordings own category content and record creation with its actor" do
    recording = Current.bucket.recordings.create!(recordable: Category.new(name: "Starters"))
    event = recording.events.sole
    assert_equal Current.bucket, recording.bucket
    assert_equal recording.recordable, event.subject
    assert_equal Current.person, event.person
    assert_equal "created", event.action
  end
end
