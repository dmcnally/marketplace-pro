require "test_helper"
require_relative "../test_helpers/catalogue_test_helper"

class ProductTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "requires a name and allows optional description and image" do
    refute Product.new(name: " ").valid?
    assert Product.new(name: "Wings").valid?
  end

  test "content is immutable" do
    assert_immutable_content Product.create!(name: "Wings")
  end

  test "rejects non-image attachments and images over the size limit" do
    product = Product.new(name: "Wings")
    product.image.attach(io: StringIO.new("plain text"), filename: "notes.txt", content_type: "text/plain")
    refute product.valid?
    assert_includes product.errors[:image], "must be a PNG, JPEG, GIF or WebP"

    large_blob = ActiveStorage::Blob.create_and_upload!(io: File.open(Rails.root.join("public/icon.png")), filename: "large.png", content_type: "image/png")
    large_blob.update!(byte_size: 11.megabytes)
    other = Product.new(name: "Wings")
    other.image.attach(large_blob)
    refute other.valid?
    assert_includes other.errors[:image], "must be smaller than 10 MB"
  end
end
