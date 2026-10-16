require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class VariantTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "requires name and a nonnegative numeric price including complimentary items" do
    assert Variant.new(name: "Default", price: "0.00").valid?
    [ nil, "", "not money", "-0.01" ].each do |price|
      refute Variant.new(name: "Default", price: price).valid?, "Accepted #{price.inspect}"
    end
    refute Variant.new(name: " ", price: "5.95").valid?
  end

  test "price and assignments are immutable content" do
    variant = Variant.create!(name: "Regular", price: "5.95")
    assert_immutable_content variant
    assert_raises(ActiveRecord::ReadOnlyRecord) { variant.reload.update!(price: "6.50") }
  end

  test "database also rejects negative prices" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Variant.transaction(requires_new: true) { Variant.insert_all!([ { name: "Invalid", price: -1, allergen_ids: [] } ]) }
    end
  end
end
