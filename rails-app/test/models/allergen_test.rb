require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class AllergenTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "requires a name and allows an absent description" do
    refute Allergen.new(name: " ").valid?
    assert Allergen.new(name: "Milk").valid?
  end

  test "wording is immutable so prior versions remain usable by snapshots" do
    assert_immutable_content Allergen.create!(name: "Milk", description: "Milk products")
  end

  test "wording edits retain both versions in a bucket-owned event" do
    recording = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Milk"))
    old_content = recording.recordable
    recording.revise_content!({ name: "Milk products", description: "Including lactose" }, revision: recording.draft_revision)
    event = recording.events.order(:id).last
    assert_equal old_content, event.subject_previous
    assert_equal "Milk", old_content.reload.name
    assert_equal "Milk products", event.subject.name
    assert_equal Current.bucket, event.bucket
    assert_equal Current.person, event.person
  end
end
