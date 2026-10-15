require "test_helper"

class PersonAllowedToTest < ActiveSupport::TestCase
  include CsvImportTestHelper

  setup do
    @person = Current.person
    @bucket = Current.bucket
    @import = create_csv_import
    @permissions = PersonAllowedTo.new(
      person: @person,
      bucket: @bucket
    )
  end

  test "allows an administrator to create imports" do
    Membership.create!(
      person: @person,
      bucket: @bucket,
      role: :admin
    )

    assert @permissions.allowed?(:create, CsvImport)
  end

  test "allows an administrator to approve an import in their bucket" do
    Membership.create!(
      person: @person,
      bucket: @bucket,
      role: :admin
    )

    assert @permissions.allowed?(:approve, @import)
  end

  test "denies an action that the policy does not allow" do
    Membership.create!(
      person: @person,
      bucket: @bucket,
      role: :viewer
    )

    assert_not @permissions.allowed?(:approve, @import)
  end

  test "denies actions when the subject has no policy" do
    assert_not @permissions.allowed?(:create, Bucket)
  end

  test "denies actions the policy does not support" do
    Membership.create!(
      person: @person,
      bucket: @bucket,
      role: :admin
    )

    assert_not @permissions.allowed?(:archive, @import)
  end

  test "uses the policy for an article recording" do
    Membership.create!(
      person: @person,
      bucket: @bucket,
      role: :admin
    )
    article = @bucket.recordings.create!(
      recordable: Article.new(title: "Example")
    )

    assert @permissions.allowed?(:publish, article)
  end

  test "uses the supplied person instead of the current person" do
    Membership.create!(
      person: @person,
      bucket: @bucket,
      role: :admin
    )
    permissions = PersonAllowedTo.new(
      person: GuestPerson.new,
      bucket: @bucket
    )

    assert_not permissions.allowed?(:approve, @import)
  end

  test "uses the supplied bucket instead of the current bucket" do
    Membership.create!(
      person: @person,
      bucket: @bucket,
      role: :admin
    )
    other_bucket = buckets(:default)
    Membership.create!(
      person: @person,
      bucket: other_bucket,
      role: :admin
    )
    permissions = PersonAllowedTo.new(
      person: @person,
      bucket: other_bucket
    )

    assert_not permissions.allowed?(:approve, @import)
  end

  test "requires an action" do
    assert_raises(ArgumentError) do
      @permissions.allowed?(nil, @import)
    end
  end

  test "requires a subject" do
    assert_raises(ArgumentError) do
      @permissions.allowed?(:approve, nil)
    end
  end
end
