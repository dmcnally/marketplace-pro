require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Catalogue::OverviewTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "overview presents published content once with current availability and archive filtering" do
    product = create_catalogue_product(name: "Published")
    regular = product.children.variants.sole
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    menu = create_catalogue_menu
    2.times { |index| add_menu_section(menu, name: "Section #{index}", product_ids: [ product.id ]) }
    publication = Menu::Publication.new(menu.reload)
    publication.publish!(token: publication.review_token)
    add_catalogue_variant(product, name: "Draft only")
    VariantAvailability.find_by!(recording: regular).update!(available: true)
    overview = Catalogue::Overview.new(Current.bucket)
    assert overview.published?
    assert_equal "Evening menu", overview.menu_name
    assert_equal "Published", overview.products.sole[:name]
    assert_equal 1, overview.products.sole[:available_count]
    assert_equal regular.id, overview.products.sole[:variants].sole[:recording].id
    assert_equal "No allergens listed", overview.products.sole[:variants].sole[:allergens]
    regular.archive_content!(revision: regular.reload.draft_revision)
    assert_empty Catalogue::Overview.new(Current.bucket).products
    assert_empty Catalogue::Overview.new(Bucket.create!(name: "Other")).products
  end
end
