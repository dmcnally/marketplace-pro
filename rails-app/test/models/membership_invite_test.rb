require "test_helper"

class MembershipInviteTest < ActiveSupport::TestCase
  test "normalizes email address and sets token digest and expiry" do
    invite = MembershipInvite.create!(
      bucket: buckets(:default),
      invited_by: people(:one),
      first_name: "fname",
      last_name: "lname",
      email_address: " Invited@Example.com ",
      role: :viewer
    )

    assert_equal "invited@example.com", invite.email_address
    assert_predicate invite.token_digest, :present?
    assert_equal invite, MembershipInvite.find_by_token(invite.token)
    assert_predicate invite.expires_at, :future?
  end

  test "uses membership roles" do
    invite = MembershipInvite.new(role: :admin)

    assert_predicate invite, :admin?
  end

  test "rejects email address for existing bucket member" do
    Membership.create!(person: people(:one), bucket: buckets(:default), role: :viewer)

    invite = MembershipInvite.new(
      bucket: buckets(:default),
      invited_by: people(:one),
      email_address: users(:one).email_address,
      role: :viewer
    )

    assert_not invite.valid?
    assert_includes invite.errors[:email_address], "already belongs to a member of this bucket"
  end

  test "rejects duplicate active invite for same bucket and email address" do
    MembershipInvite.create!(
      bucket: buckets(:default),
      invited_by: people(:one),
      first_name: "fname",
      last_name: "lname",
      email_address: "invited@example.com",
      role: :viewer
    )

    invite = MembershipInvite.new(
      bucket: buckets(:default),
      invited_by: people(:one),
      first_name: "fname",
      last_name: "lname",
      email_address: "INVITED@example.com",
      role: :editor
    )

    assert_not invite.valid?
    assert_includes invite.errors[:email_address], "already has an active invitation for this bucket"
  end

  test "cancel revokes invitation" do
    invite = MembershipInvite.create!(
      bucket: buckets(:default),
      invited_by: people(:one),
      first_name: "fname",
      last_name: "lname",
      email_address: "invited@example.com",
      role: :viewer
    )

    invite.cancel!

    assert_predicate invite, :revoked?
  end
end
