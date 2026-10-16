require "test_helper"

module Invitations
  class AcceptancesControllerTest < ActionDispatch::IntegrationTest
    test "create accepts invitation for signed-in user without bucket access" do
      invitation = membership_invite(role: :editor)
      user = users(:two)
      sign_in_as user

      assert_difference -> { Membership.count }, 1 do
        post accept_invitation_path(invitation.token)
      end

      membership = Membership.last
      assert_redirected_to overview_path
      assert_equal user.person, membership.person
      assert_equal buckets(:default), membership.bucket
      assert_predicate membership, :editor?
      assert_equal user.person, invitation.reload.accepted_by
      assert_predicate invitation, :accepted?

      follow_redirect!
      assert_response :success
    end

    test "create clears pending authentication return path after successful acceptance" do
      invitation = membership_invite
      user = users(:two)

      post accept_invitation_path(invitation.token)
      assert_redirected_to new_session_path

      sign_in_as user
      post accept_invitation_path(invitation.token)
      assert_redirected_to overview_path

      delete session_path

      post session_path, params: { email_address: user.email_address, password: "password" }

      assert_redirected_to overview_path
    end

    test "create redirects to invitation when acceptance fails" do
      invitation = membership_invite(role: :admin)
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :viewer)
      sign_in_as user

      assert_no_difference -> { Membership.count } do
        post accept_invitation_path(invitation.token)
      end

      assert_redirected_to invitation_path(invitation.token)
      assert_nil invitation.reload.accepted_at

      follow_redirect!
      assert_select ".login__alert", "You already have access to this bucket."
    end

    test "create redirects guests to sign in" do
      invitation = membership_invite

      assert_no_difference -> { Membership.count } do
        post accept_invitation_path(invitation.token)
      end

      assert_redirected_to new_session_path
    end

    test "create stores invitation page as return path for guests" do
      invitation = membership_invite

      post accept_invitation_path(invitation.token)
      post session_path, params: { email_address: users(:two).email_address, password: "password" }

      assert_redirected_to invitation_path(invitation.token)
      assert_nil invitation.reload.accepted_at
    end

    test "create redirects invalid token to invitation page" do
      sign_in_as users(:two)

      assert_no_difference -> { Membership.count } do
        post accept_invitation_path("invalid-token")
      end

      assert_redirected_to invitation_path("invalid-token")
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
end
