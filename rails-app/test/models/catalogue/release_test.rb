require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Catalogue::ReleaseTest < ActiveSupport::TestCase
  include CatalogueTestHelper

  test "release must agree with its recording bucket kind and snapshot ownership" do
    product = create_catalogue_product
    snapshot = Catalogue::Snapshot.create!(recording: product, content: { "name" => "Wings" })
    release = Catalogue::Release.new(recording: product, bucket: Current.bucket, kind: "Product", snapshot: snapshot)
    assert release.valid?
    release.bucket = Bucket.create!(name: "Wrong bucket")
    refute release.valid?
    release.bucket = Current.bucket
    release.kind = "Menu"
    refute release.valid?
    release.kind = "Product"
    release.snapshot = Catalogue::Snapshot.create!(recording: create_catalogue_product, content: { "name" => "Other" })
    refute release.valid?
    assert release.errors[:snapshot].any?
  end

  test "one recording cannot have two independent release states" do
    product = create_catalogue_product
    snapshot = Catalogue::Snapshot.create!(recording: product, content: { "name" => "Wings" })
    attributes = { recording: product, bucket: Current.bucket, kind: "Product", snapshot: snapshot }
    Catalogue::Release.create!(attributes)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Catalogue::Release.transaction(requires_new: true) { Catalogue::Release.create!(attributes) }
    end
  end
end
