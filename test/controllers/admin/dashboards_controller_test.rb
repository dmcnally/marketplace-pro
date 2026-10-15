require "test_helper"

module Admin
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    test "show allows bucket admins" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      get admin_root_path

      assert_response :success
      assert_select "h1", "Welcome back, Jane"
      assert_select ".workspace__nav-link[aria-current=page]", "Overview"
      assert_select ".workspace-metric h2", "Team members"
      assert_select ".workspace-metric__value", "1"
      assert_select ".workspace-card__item p", "0 invitations still pending"
      assert_select "a[href=?]", new_article_path, text: "Create article"
      assert_select "a[href=?]", new_admin_invitation_path, text: "Invite member"
      assert_select "#workspace-name[readonly][value=Default]"
    end

    test "show displays current bucket member and sent invitation counts" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      MembershipInvite.create!(
        bucket: buckets(:default),
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "sent@example.com",
        role: :viewer
      )
      MembershipInvite.create!(
        bucket: buckets(:default),
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "expired@example.com",
        role: :viewer,
        expires_at: 1.day.ago
      )
      sign_in_as user

      get admin_root_path

      assert_response :success
      assert_select ".workspace-metric h2", "Team members"
      assert_select ".workspace-metric__value", "1"
      assert_select ".workspace-card__item p", "1 invitation still pending"
    end

    test "show redirects guests to sign in" do
      get admin_root_path

      assert_redirected_to new_session_path
    end

    test "show forbids signed-in non-admins" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :viewer)
      sign_in_as user

      get admin_root_path

      assert_response :forbidden
    end

    test "dashboard route points to show" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      get admin_dashboard_path

      assert_response :success
      assert_select "h1", "Welcome back, Jane"
    end
  end
end
