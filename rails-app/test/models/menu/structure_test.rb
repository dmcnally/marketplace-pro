require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Menu::StructureTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "ordering requires a complete permutation and records an immutable change" do
    menu = create_catalogue_menu
    first = add_menu_section(menu)
    second = add_menu_section(menu, name: "Mains")
    menu.reload
    structure = Menu::Structure.new(menu)
    previous = menu.recordable
    [ [ first.id ], [ first.id, first.id ], [ first.id, -1 ] ].each do |order|
      assert_raises(ArgumentError) { structure.reorder!(order, revision: menu.draft_revision) }
    end
    structure.reorder!([ second.id, first.id ], revision: menu.draft_revision)
    assert_equal [ second.id, first.id ], structure.sections.map(&:id)
    assert_equal [ first.id, second.id ], previous.reload.section_order
    assert_equal previous, menu.events.where(action: "updated").order(:id).last.subject_previous
  end

  test "removing a section changes only draft structure and preserves its content and history" do
    menu = create_catalogue_menu
    section = add_menu_section(menu)
    structure = Menu::Structure.new(menu.reload)
    assert_no_difference([ "MenuSection.count", "Recording.count" ]) { structure.remove!(section, revision: menu.draft_revision) }
    assert_empty structure.sections
    assert section.reload.kept?
    assert section.events.exists?
    assert_raises(ActiveRecord::RecordNotFound) { structure.remove!(section, revision: menu.draft_revision) }
  end
end
