require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:two) }

  test "new" do
    get new_session_path
    assert_response :success
    assert_select "a[href='#{new_registration_path}']", "Create account"
  end

  test "create with valid credentials" do
    Membership.create!(person: @user.person, bucket: Current.bucket, role: :viewer)

    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with valid credentials redirects users without content buckets to the error page" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to no_bucket_path
    assert cookies[:session_id]
  end

  test "create with valid credentials redirects users without content buckets to pending invitation" do
    invitation = MembershipInvite.create!(
      bucket: buckets(:default),
      invited_by: people(:one),
      first_name: "fname",
      last_name: "lname",
      email_address: "invited@example.com",
      role: :viewer
    )

    get invitation_path(invitation.token)
    post accept_invitation_path(invitation.token)
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to invitation_path(invitation.token)
    assert cookies[:session_id]
  end

  test "create with valid sys admin credentials redirects to sys admin without selecting a content bucket" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }

    assert_redirected_to sys_admin_root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
