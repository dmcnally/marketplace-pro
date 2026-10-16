require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class MenuSection::PlacementsTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "product ordering is section specific immutable and rejects missing or duplicate placements" do
    menu = create_catalogue_menu
    products = [ create_catalogue_product, create_catalogue_product(name: "Bread") ]
    first = add_menu_section(menu, product_ids: products.map(&:id))
    second = add_menu_section(menu, product_ids: products.map(&:id))
    menu.reload
    placements = MenuSection::Placements.new(menu, first)
    [ [], [ products.first.id, products.first.id ], [ -1, products.last.id ] ].each do |ids|
      assert_raises(ArgumentError) { placements.reorder!(ids, revision: menu.draft_revision) }
    end
    old = first.recordable
    revision = menu.draft_revision
    placements.reorder!(products.reverse.map(&:id), revision: revision)
    assert_equal products.reverse.map(&:id), first.reload.recordable.product_ids
    assert_equal products.map(&:id), second.reload.recordable.product_ids
    assert_equal products.map(&:id), old.reload.product_ids
    assert_equal Current.person, first.events.where(action: "updated").sole.person
    assert_raises(Recording::CatalogueEditing::StaleDraft) { placements.reorder!(products.map(&:id), revision: revision) }
    other = create_catalogue_menu
    assert_raises(ActiveRecord::RecordNotFound) { MenuSection::Placements.new(other, first).reorder!(products.map(&:id), revision: other.draft_revision) }
  end
end
