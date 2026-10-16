require "test_helper"

class BucketTest < ActiveSupport::TestCase
  test "currency defaults to GBP and requires an uppercase three-letter code" do
    assert_equal "GBP", Bucket.new.currency
    assert Bucket.new(name: "Euro shop", currency: "EUR").valid?
    [ nil, "", "gbp", "POUNDS" ].each do |currency|
      refute Bucket.new(name: "Invalid currency", currency: currency).valid?
    end
  end

  test "name is required" do
    bucket = Bucket.new

    refute bucket.valid?
    assert_includes bucket.errors[:name], "can't be blank"
  end

  test "name must be unique" do
    bucket = Bucket.new(name: buckets(:default).name)

    refute bucket.valid?
    assert_includes bucket.errors[:name], "has already been taken"
  end

  test "system_bucket returns the reserved system bucket" do
    assert_equal buckets(:system), Bucket.system_bucket
    assert buckets(:system).system_bucket?
    assert buckets(:system).system?
    refute buckets(:default).system_bucket?
  end

  test "identity returns the reserved identity bucket" do
    assert_equal buckets(:identity), Bucket.identity
    assert buckets(:identity).identity?
    assert buckets(:identity).system?
    refute buckets(:default).identity?
  end

  test "content excludes system buckets" do
    assert_includes Bucket.content, buckets(:default)
    refute_includes Bucket.content, buckets(:system)
    refute_includes Bucket.content, buckets(:identity)
  end

  test "system bucket name cannot change" do
    bucket = buckets(:system)
    bucket.name = "System Team"

    refute bucket.valid?
    assert_includes bucket.errors[:name], "can't be changed for the system bucket"
  end

  test "identity bucket name cannot change" do
    bucket = buckets(:identity)
    bucket.name = "Identity Team"

    refute bucket.valid?
    assert_includes bucket.errors[:name], "can't be changed for the identity bucket"
  end
end
