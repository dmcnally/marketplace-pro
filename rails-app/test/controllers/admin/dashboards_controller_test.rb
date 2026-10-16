require "test_helper"

module Admin
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    test "show allows bucket admins" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      get admin_root_path

      assert_response :success
      assert_select "h1", "Manage users"
      assert_select ".management-sidebar__link--active", "Dashboard"
      assert_select ".dashboard-summary__label", "Team members"
      assert_select ".dashboard-summary__value", "1"
      assert_select ".dashboard-summary__item p", "0 invitations still pending"
      assert_select "a[href=?]", new_article_path, count: 0
      assert_select "a[href=?]", new_admin_invitation_path, text: "Invite member"
      assert_select "nav[aria-label=Admin] a" do |links|
        assert_equal [ "Dashboard", "Members", "Invitations", "Back to Overview" ], links.map(&:text)
      end
      [ articles_path, admin_csv_imports_path, admin_products_path, admin_categories_path, admin_allergens_path, admin_menus_path ].each do |path|
        assert_select "main a[href=?]", path, count: 0
      end
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
      assert_select ".dashboard-summary__label", "Team members"
      assert_select ".dashboard-summary__value", "1"
      assert_select ".dashboard-summary__item p", "1 invitation still pending"
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
      assert_select "h1", "Manage users"
    end
  end
end
