require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Catalogue::PublicationDiffTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "product comparisons retain published prices and allergen wording after subsequent edits" do
    product = create_catalogue_product
    variant = product.children.variants.sole
    allergen = Current.bucket.recordings.create!(recordable: Allergen.new(name: "Milk", description: "Dairy"))
    first = publish(product, Product::Publication)
    variant.update!(recordable: Variant.new(name: "Large", price: "8.50", allergen_ids: [ allergen.id ]))
    second = publish(product.reload, Product::Publication)
    variant.update!(recordable: Variant.new(name: "Draft", price: "99"))
    allergen.update!(recordable: Allergen.new(name: "Changed later"))
    changes = Catalogue::PublicationDiff.new(second).changes
    assert_includes changes, { field: "Variant: Large · Price", before: "5.95", after: "8.5" }
    assert_includes changes, { field: "Variant: Large · Allergens", before: "", after: "Milk: Dairy" }
    refute changes.any? { |change| change[:field] == "Variant order" }
    assert Catalogue::PublicationDiff.new(first).first_publication?
    refute Catalogue::PublicationDiff.new(second).first_publication?
    assert_equal [], Catalogue::PublicationDiff.new(variant.events.order(:id).last).changes
  end

  test "menu comparisons include section placement changes and exclude unpublished empty sections" do
    product = create_catalogue_product
    publish(product, Product::Publication)
    menu = create_catalogue_menu
    section = add_menu_section(menu, product_ids: [ product.id ])
    add_menu_section(menu, name: "Empty")
    first = publish(menu, Menu::Publication)
    section.update!(recordable: MenuSection.new(name: "Sharing", product_ids: [ product.id ]))
    second = publish(menu.reload, Menu::Publication)
    changes = Catalogue::PublicationDiff.new(second).changes
    assert_includes changes, { field: "Section: Sharing · Name", before: "Starters", after: "Sharing" }
    refute changes.any? { |change| change[:field] == "Section order" }
    first_changes = Catalogue::PublicationDiff.new(first).changes
    assert_includes first_changes, { field: "Section: Starters · Products", before: nil, after: "Wings" }
    refute first_changes.any? { |change| change[:field].include?("Empty") }
  end

  test "missing or foreign snapshots cannot be displayed as this recording publication" do
    product = create_catalogue_product
    other = create_catalogue_product
    foreign_event = publish(other, Product::Publication)
    event = product.events.create!(bucket: Current.bucket, subject: product.recordable, action: "published")
    refute Catalogue::PublicationDiff.new(event).available?
    event.details.create!(key: "snapshot_id", value: foreign_event.details.find_by!(key: "snapshot_id").value)
    refute Catalogue::PublicationDiff.new(event.reload).available?
  end

  test "republication compares the immediately preceding snapshot and records removals and ordering" do
    freeze_time do
      product = create_catalogue_product
      regular = product.children.variants.sole
      large = add_catalogue_variant(product)
      publish(product, Product::Publication)
      product.update!(recordable: Product.new(name: "Wings", variant_order: [ large.id, regular.id ]))
      reordered = publish(product, Product::Publication)
      assert_includes Catalogue::PublicationDiff.new(reordered).changes,
        { field: "Variant order", before: "Default, Large", after: "Large, Default" }
      unchanged = publish(product, Product::Publication)
      assert_empty Catalogue::PublicationDiff.new(unchanged).changes
      regular.archive_content!(revision: regular.reload.draft_revision)
      removed = publish(product, Product::Publication)
      assert_includes Catalogue::PublicationDiff.new(removed).changes,
        { field: "Variant: Default · Price", before: "5.95", after: nil }
    end
  end

  private

  def publish(recording, klass)
    publication = klass.new(recording.reload)
    publication.publish!(token: publication.review_token)
    recording.events.where(action: "published").order(:id).last
  end
end
