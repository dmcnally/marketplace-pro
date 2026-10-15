require "test_helper"

module SysAdmin
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    test "show allows sys admins" do
      sign_in_as users(:one)

      get sys_admin_root_path

      assert_response :success
      assert_select "h1", "Sys Admin"
      assert_select ".management-sidebar__link", "Buckets"
      assert_select ".management-sidebar__link", "Users"
      assert_select ".dashboard-summary__label", "Buckets"
      assert_select ".dashboard-summary__value", Bucket.count.to_s
      assert_select ".dashboard-summary__label", "Users"
      assert_select ".dashboard-summary__value", User.count.to_s
    end

    test "show redirects guests to sign in" do
      get sys_admin_root_path

      assert_redirected_to new_session_path
    end

    test "show forbids signed-in non-sys-admins" do
      sign_in_as users(:two)

      get sys_admin_root_path

      assert_response :forbidden
    end

    test "dashboard route points to show" do
      sign_in_as users(:one)

      get sys_admin_dashboard_path

      assert_response :success
      assert_select "h1", "Sys Admin"
    end
  end
end
