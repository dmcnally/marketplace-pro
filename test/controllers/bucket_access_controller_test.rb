require "test_helper"

class BucketAccessControllerTest < ActionDispatch::IntegrationTest
  test "show redirects guests to sign in" do
    get no_bucket_path

    assert_redirected_to new_session_path
  end

  test "show tells signed-in users to contact an admin" do
    sign_in_as users(:two)

    get no_bucket_path

    assert_response :success
    assert_select "h1", "No bucket access"
    assert_select ".empty-state__hint", "Your account is not assigned to a bucket. Contact an admin to get access."
  end
end
