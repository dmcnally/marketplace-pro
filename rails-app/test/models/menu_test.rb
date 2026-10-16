require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class MenuTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "menu content is immutable and requires a name" do
    refute Menu.new(name: " ").valid?
    menu = Menu.create!(name: "Evening")
    assert_immutable_content menu
    assert_empty menu.section_order
    assert menu.diffable?
  end

  test "menu images use the supported image types and size limit" do
    menu = Menu.new(name: "Evening")
    menu.image.attach(io: StringIO.new("text"), filename: "menu.txt", content_type: "text/plain")
    refute menu.valid?
    assert menu.errors[:image].any?
  end
end
