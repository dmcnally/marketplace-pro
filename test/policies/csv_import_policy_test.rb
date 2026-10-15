require "test_helper"

class CsvImportPolicyTest < ActiveSupport::TestCase
  include CsvImportTestHelper

  setup do
    @person = Current.person
    @bucket = Current.bucket
    @import = create_csv_import
    @policy = CsvImportPolicy.new(person: @person, bucket: @bucket)
  end

  test "allows administrators to manage imports in their bucket" do
    Membership.create!(person: @person, bucket: @bucket, role: :admin)

    assert @policy.can_create?
    assert @policy.can_view?
    assert @policy.can_view?(@import)
    assert @policy.can_approve?(@import)
    assert @policy.can_delete?(@import)
  end

  test "denies editors access to imports" do
    Membership.create!(person: @person, bucket: @bucket, role: :editor)

    assert_not @policy.can_create?
    assert_not @policy.can_view?
    assert_not @policy.can_view?(@import)
    assert_not @policy.can_approve?(@import)
    assert_not @policy.can_delete?(@import)
  end

  test "denies viewers access to imports" do
    Membership.create!(person: @person, bucket: @bucket, role: :viewer)

    assert_not @policy.can_create?
    assert_not @policy.can_view?
    assert_not @policy.can_view?(@import)
    assert_not @policy.can_approve?(@import)
    assert_not @policy.can_delete?(@import)
  end

  test "denies people who are not members of the bucket" do
    assert_not @policy.can_create?
    assert_not @policy.can_view?
    assert_not @policy.can_view?(@import)
    assert_not @policy.can_approve?(@import)
    assert_not @policy.can_delete?(@import)
  end

  test "denies guests access to imports" do
    policy = CsvImportPolicy.new(person: GuestPerson.new, bucket: @bucket)

    assert_not policy.can_create?
    assert_not policy.can_view?
    assert_not policy.can_view?(@import)
    assert_not policy.can_approve?(@import)
    assert_not policy.can_delete?(@import)
  end

  test "denies administrators access to imports outside the selected bucket" do
    other_bucket = buckets(:default)
    Membership.create!(person: @person, bucket: @bucket, role: :admin)
    Membership.create!(person: @person, bucket: other_bucket, role: :admin)
    other_import = create_csv_import(bucket: other_bucket)

    assert_not @policy.can_view?(other_import)
    assert_not @policy.can_approve?(other_import)
    assert_not @policy.can_delete?(other_import)
  end

  test "allows system administrators to manage imports in the selected bucket" do
    policy = CsvImportPolicy.new(person: users(:one).person, bucket: @bucket)

    assert policy.can_create?
    assert policy.can_view?
    assert policy.can_view?(@import)
    assert policy.can_approve?(@import)
    assert policy.can_delete?(@import)
  end

  test "denies system administrators access to imports outside the selected bucket" do
    policy = CsvImportPolicy.new(
      person: users(:one).person,
      bucket: buckets(:default)
    )

    assert_not policy.can_view?(@import)
    assert_not policy.can_approve?(@import)
    assert_not policy.can_delete?(@import)
  end

  test "denies access when no bucket is selected" do
    policy = CsvImportPolicy.new(person: users(:one).person, bucket: nil)

    assert_not policy.can_create?
    assert_not policy.can_view?
    assert_not policy.can_view?(@import)
    assert_not policy.can_approve?(@import)
    assert_not policy.can_delete?(@import)
  end

  test "does not grant access for an unaccepted administrator invitation" do
    invited_user = users(:two)
    MembershipInvite.create!(
      bucket: @bucket,
      invited_by: @person,
      role: :admin,
      email_address: invited_user.email_address,
      first_name: "Invited",
      last_name: "Person"
    )
    policy = CsvImportPolicy.new(person: invited_user.person, bucket: @bucket)

    assert_not policy.can_create?
    assert_not policy.can_view?
    assert_not policy.can_view?(@import)
    assert_not policy.can_approve?(@import)
    assert_not policy.can_delete?(@import)
  end
end
