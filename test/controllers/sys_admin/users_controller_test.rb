require "test_helper"

module SysAdmin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as users(:one)
    end

    test "index lists users" do
      get sys_admin_users_path

      assert_response :success
      assert_select "h1", "Users"
      assert_select ".management-sidebar__link--active", "Users"
      assert_select ".user-list__email", users(:one).email_address
      assert_select ".user-list__email", users(:two).email_address
      assert_select ".user-list__meta", people(:one).person_card.name
    end

    test "show displays user details" do
      Membership.create!(person: people(:two), bucket: buckets(:default), role: :editor)

      get sys_admin_user_path(users(:two))

      assert_response :success
      assert_select "h1", users(:two).email_address
      assert_select ".user-detail__description", people(:two).person_card.name
      assert_select ".user-detail__term", "Sessions"
      assert_select "#user-buckets-title", "Buckets"
      assert_select ".user-buckets__name", buckets(:default).name
      assert_select ".user-buckets__meta", "Editor"
      assert_select "a[href='#{sys_admin_bucket_path(buckets(:default))}']", "View"
      assert_select "form.user-detail__action-form[action='#{sys_admin_user_password_path(users(:two))}']" do
        assert_select "button", "Reset Password"
      end
      assert_equal "Send password reset instructions to #{users(:two).email_address}?", css_select("form.user-detail__action-form").first["data-turbo-confirm"]
    end

    test "show displays empty bucket access state" do
      get sys_admin_user_path(users(:two))

      assert_response :success
      assert_select ".empty-state__message", "No bucket access."
    end

    test "guests are redirected to sign in" do
      sign_out

      get sys_admin_users_path

      assert_redirected_to new_session_path
    end
  end
end
