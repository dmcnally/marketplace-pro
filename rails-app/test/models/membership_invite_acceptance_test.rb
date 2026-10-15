require "test_helper"

class MembershipInviteAcceptanceTest < ActiveSupport::TestCase
  test "accepts active invitation for person" do
    invitation = membership_invite(role: :editor)
    person = people(:two)

    assert_difference -> { Membership.count }, 1 do
      result = invitation.accept_for(person)

      assert_predicate result, :success?
      assert_equal "Invitation accepted.", result.message
      assert_equal person, result.membership.person
      assert_equal buckets(:default), result.membership.bucket
      assert_predicate result.membership, :editor?
    end

    invitation.reload
    assert_predicate invitation, :accepted?
    assert_equal person, invitation.accepted_by
    assert_predicate invitation.accepted_at, :present?
  end

  test "acceptance uses invite role without depending on invited email address" do
    invitation = membership_invite(email_address: "someone-else@example.com", role: :admin)
    person = people(:two)

    result = MembershipInviteAcceptance.call(invitation:, person:)

    assert_predicate result, :success?
    assert_predicate result.membership, :admin?
    assert_equal person, result.membership.person
  end

  test "acceptance succeeds when invited email belongs to accepting person" do
    invitation = membership_invite(email_address: users(:two).email_address, role: :viewer)

    assert_difference -> { Membership.count }, 1 do
      result = invitation.accept_for(users(:two).person)

      assert_predicate result, :success?
    end

    assert_predicate invitation.reload, :accepted?
    assert_equal users(:two).person, invitation.accepted_by
  end

  test "does not accept expired invitation" do
    invitation = membership_invite(expires_at: 1.day.ago)

    assert_no_difference -> { Membership.count } do
      result = invitation.accept_for(people(:two))

      assert_not result.success?
      assert_equal "Invitation has expired.", result.message
    end

    assert_nil invitation.reload.accepted_at
  end

  test "does not accept revoked invitation" do
    invitation = membership_invite(revoked_at: Time.current)

    assert_no_difference -> { Membership.count } do
      result = invitation.accept_for(people(:two))

      assert_not result.success?
      assert_equal "Invitation has been revoked.", result.message
    end

    assert_nil invitation.reload.accepted_at
  end

  test "does not accept already accepted invitation" do
    invitation = membership_invite(accepted_at: Time.current, accepted_by: people(:one))

    assert_no_difference -> { Membership.count } do
      result = invitation.accept_for(people(:two))

      assert_not result.success?
      assert_equal "Invitation has already been accepted.", result.message
    end
  end

  test "does not create duplicate membership or change role for existing member" do
    invitation = membership_invite(role: :admin)
    membership = Membership.create!(person: people(:two), bucket: buckets(:default), role: :viewer)

    assert_no_difference -> { Membership.count } do
      result = invitation.accept_for(people(:two))

      assert_not result.success?
      assert_equal "You already have access to this bucket.", result.message
    end

    assert_predicate membership.reload, :viewer?
    assert_nil invitation.reload.accepted_at
  end

  test "requires a person" do
    invitation = membership_invite

    assert_no_difference -> { Membership.count } do
      result = invitation.accept_for(GuestPerson.new)

      assert_not result.success?
      assert_equal "Sign in to accept this invitation.", result.message
    end
  end

  private

  def membership_invite(attributes = {})
    MembershipInvite.create!(
      {
        bucket: buckets(:default),
        invited_by: people(:one),
        first_name: "fname",
        last_name: "lname",
        email_address: "invited-#{SecureRandom.hex(4)}@example.com",
        role: :viewer
      }.merge(attributes)
    )
  end
end
