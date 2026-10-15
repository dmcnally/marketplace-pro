require "test_helper"

module SysAdmin
  module Users
    class PasswordsControllerTest < ActionDispatch::IntegrationTest
      setup do
        sign_in_as users(:one)
      end

      test "create sends password reset instructions" do
        post sys_admin_user_password_path(users(:two))

        assert_enqueued_email_with PasswordsMailer, :reset, args: [ users(:two) ]
        assert_redirected_to sys_admin_user_path(users(:two))
      end

      test "guests are redirected to sign in" do
        sign_out

        post sys_admin_user_password_path(users(:two))

        assert_enqueued_emails 0
        assert_redirected_to new_session_path
      end
    end
  end
end
