require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "sys_admin? returns true for system bucket admins" do
    Membership.create!(person: Current.person, bucket: buckets(:system), role: :admin)

    assert Current.person.sys_admin?
  end

  test "sys_admin? returns false for non-admin system bucket members" do
    Membership.create!(person: Current.person, bucket: buckets(:system), role: :editor)

    refute Current.person.sys_admin?
  end

  test "sys_admin? returns false without system bucket membership" do
    refute Current.person.sys_admin?
  end

  test "preferred_content_bucket returns the requested content bucket membership" do
    first_bucket = Bucket.create!(name: "First")
    second_bucket = Bucket.create!(name: "Second")
    Membership.create!(person: Current.person, bucket: first_bucket, role: :viewer)
    Membership.create!(person: Current.person, bucket: second_bucket, role: :viewer)

    assert_equal second_bucket, Current.person.preferred_content_bucket(second_bucket.id)
  end

  test "preferred_content_bucket excludes system bucket preferences" do
    content_bucket = Bucket.create!(name: "Content")
    Membership.create!(person: Current.person, bucket: content_bucket, role: :viewer)

    assert_equal content_bucket, Current.person.preferred_content_bucket(buckets(:system).id)
  end

  test "preferred_content_bucket excludes identity bucket preferences" do
    content_bucket = Bucket.create!(name: "Identity Excluded Content")
    Membership.create!(person: Current.person, bucket: content_bucket, role: :viewer)

    assert_equal content_bucket, Current.person.preferred_content_bucket(buckets(:identity).id)
  end

  test "preferred_content_bucket falls back when the requested bucket is unavailable" do
    content_bucket = Bucket.create!(name: "Available")
    unavailable_bucket = Bucket.create!(name: "Unavailable")
    Membership.create!(person: Current.person, bucket: content_bucket, role: :viewer)

    assert_equal content_bucket, Current.person.preferred_content_bucket(unavailable_bucket.id)
  end

  test "preferred_content_bucket returns nil without content memberships" do
    assert_nil Current.person.preferred_content_bucket(buckets(:system).id)
  end

  test "identity bucket is not switchable content" do
    Membership.create!(person: Current.person, bucket: buckets(:identity), role: :admin)

    refute Current.person.switchable_content_bucket?(buckets(:identity))
  end

  test "preferred_content_bucket lets sys admins select any content bucket" do
    content_bucket = Bucket.create!(name: "Sys Admin Selected")
    Membership.create!(person: Current.person, bucket: buckets(:system), role: :admin)

    assert_equal content_bucket, Current.person.preferred_content_bucket(content_bucket.id)
  end

  test "preferred_content_bucket does not implicitly select a content bucket for sys admins" do
    Bucket.create!(name: "Sys Admin Available")
    Membership.create!(person: Current.person, bucket: buckets(:system), role: :admin)

    assert_nil Current.person.preferred_content_bucket(nil)
  end
end
