require "test_helper"

class Buckets::SwitchControllerTest < ActionDispatch::IntegrationTest
  test "create stores the selected content bucket for sys admins" do
    sign_in_as users(:one)
    selected_bucket = Bucket.create!(name: "Selected Bucket")

    post bucket_switch_path(selected_bucket), headers: { "HTTP_REFERER" => sys_admin_buckets_url }

    assert_redirected_to root_path

    get articles_path

    assert_response :success
    assert_select ".site-header__bucket", selected_bucket.name
  end

  test "create stores bucket memberships for non-sys-admins" do
    sign_in_as users(:two)
    selected_bucket = Bucket.create!(name: "Member Bucket")
    Membership.create!(person: users(:two).person, bucket: selected_bucket, role: :viewer)

    post bucket_switch_path(selected_bucket)

    assert_redirected_to root_path

    get articles_path

    assert_response :success
    assert_select ".site-header__bucket", selected_bucket.name
  end

  test "create does not select the system bucket" do
    sign_in_as users(:one)
    selected_bucket = Bucket.create!(name: "Selected Bucket")

    post bucket_switch_path(selected_bucket)
    post bucket_switch_path(buckets(:system))
    get articles_path

    assert_response :success
    assert_select ".site-header__bucket", selected_bucket.name
  end

  test "destroy clears the selected content bucket for sys admins" do
    sign_in_as users(:one)
    selected_bucket = Bucket.create!(name: "Selected Bucket")

    post bucket_switch_path(selected_bucket)
    delete bucket_switch_path(selected_bucket)

    assert_redirected_to sys_admin_root_path

    get articles_path

    assert_redirected_to sys_admin_buckets_path
  end

  test "destroy forbids non-sys-admins" do
    sign_in_as users(:two)
    selected_bucket = Bucket.create!(name: "Member Bucket")
    Membership.create!(person: users(:two).person, bucket: selected_bucket, role: :viewer)

    post bucket_switch_path(selected_bucket)
    delete bucket_switch_path(selected_bucket)

    assert_response :forbidden
  end

  test "create does not select the identity bucket" do
    sign_in_as users(:one)
    selected_bucket = Bucket.create!(name: "Selected Bucket")

    post bucket_switch_path(selected_bucket)
    post bucket_switch_path(buckets(:identity))
    get articles_path

    assert_response :success
    assert_select ".site-header__bucket", selected_bucket.name
  end

  test "create forbids inaccessible buckets" do
    sign_in_as users(:two)

    post bucket_switch_path(buckets(:default))

    assert_response :forbidden
  end

  test "guests are redirected to sign in" do
    post bucket_switch_path(buckets(:default))

    assert_redirected_to new_session_path
  end
end
