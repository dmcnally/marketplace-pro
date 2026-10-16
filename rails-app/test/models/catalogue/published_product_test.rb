require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Catalogue::PublishedProductTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "only published variants are exposed and availability remains live" do
    product = create_catalogue_product
    publication = Product::Publication.new(product)
    publication.publish!(token: publication.review_token)
    original = product.children.variants.sole
    extra = add_catalogue_variant(product)
    published = Catalogue::PublishedProduct.new(product)
    assert_equal [ original.id ], published.variants.map { |variant| variant.fetch("id") }
    refute_includes published.variants.map { |variant| variant.fetch("id") }, extra.id
    state = VariantAvailability.find_by!(recording: original)
    assert_equal "Sold out", published.availability_for(published.variants.sole)
    state.update!(available: true)
    assert_equal "Available", published.availability_for(published.variants.sole)
    publication.unpublish!(token: publication.review_token)
    refute Catalogue::PublishedProduct.new(product).published?
  end
end
