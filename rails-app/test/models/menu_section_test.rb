require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class MenuSectionTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "section requires a name and rejects duplicate product placements" do
    refute MenuSection.new(name: "").valid?
    refute MenuSection.new(name: "Starters", product_ids: [ 1, 1 ]).valid?
    assert MenuSection.new(name: "Starters", product_ids: [ 1, 2 ]).valid?
    assert_immutable_content MenuSection.create!(name: "Starters")
  end

  test "section images reject unsupported files" do
    section = MenuSection.new(name: "Starters")
    section.image.attach(io: StringIO.new("text"), filename: "section.txt", content_type: "text/plain")
    refute section.valid?
    assert section.errors[:image].any?
  end
end
