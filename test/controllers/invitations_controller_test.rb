require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  test "show displays active invitation for guests" do
    invitation = MembershipInvite.create!(
      bucket: buckets(:default),
      invited_by: people(:one),
      first_name: "fname",
      last_name: "lname",
      email_address: "invited@example.com",
      role: :editor
    )

    get invitation_path(invitation.token)

    assert_response :success
    assert_select "h1", "You have been invited to Default"
    assert_select ".empty-state__hint", /editor access/
    assert_select "form[action='#{accept_invitation_path(invitation.token)}']" do
      assert_select "button", "Accept Invitation"
    end
  end

  test "show displays invitation for signed-in user without bucket access" do
    invitation = MembershipInvite.create!(
      bucket: buckets(:default),
      invited_by: people(:one),
      first_name: "fname",
      last_name: "lname",
      email_address: "invited@example.com",
      role: :viewer
    )
    sign_in_as users(:two)

    get invitation_path(invitation.token)

    assert_response :success
    assert_select "h1", "You have been invited to Default"
    assert_select "form[action='#{accept_invitation_path(invitation.token)}']" do
      assert_select "button", "Accept Invitation"
    end
  end

  test "show displays not found page for invalid token" do
    get invitation_path("invalid-token")

    assert_response :not_found
    assert_select "h1", "Invitation not found"
  end

  test "show displays expired invitation page" do
    invitation = MembershipInvite.create!(
      bucket: buckets(:default),
      invited_by: people(:one),
      first_name: "fname",
      last_name: "lname",
      email_address: "invited@example.com",
      role: :viewer,
      expires_at: 1.day.ago
    )

    get invitation_path(invitation.token)

    assert_response :success
    assert_select "h1", "Invitation expired"
  end
end
