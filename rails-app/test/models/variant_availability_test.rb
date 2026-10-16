require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class VariantAvailabilityTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "new variants start unavailable and have exactly one operational state row" do
    product = create_catalogue_product
    variant = product.children.variants.sole
    refute VariantAvailability.find_by!(recording: variant).available?
    duplicate = VariantAvailability.new(recording: variant)
    refute duplicate.valid?
    assert_includes duplicate.errors[:recording_id], "has already been taken"
  end

  test "rejects non-variant recordings and absent recordings" do
    product = create_catalogue_product
    refute VariantAvailability.new(recording: product).valid?
    refute VariantAvailability.new.valid?
  end
end
