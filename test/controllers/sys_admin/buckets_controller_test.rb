require "test_helper"

module SysAdmin
  class BucketsControllerTest < ActionDispatch::IntegrationTest
    setup do
      sign_in_as users(:one)
    end

    test "index lists buckets" do
      get sys_admin_buckets_path

      assert_response :success
      assert_select "h1", "Buckets"
      assert_select ".bucket-list__name", buckets(:default).name
      assert_select "a", text: "New Bucket"
      assert_select "a[href='#{sys_admin_bucket_path(buckets(:default))}']", "View"
      assert_select "form[action='#{bucket_switch_path(buckets(:default))}'] button", "Switch"
      assert_select "form[action='#{bucket_switch_path(buckets(:system))}']", count: 0
      assert_select "form[action='#{bucket_switch_path(buckets(:identity))}']", count: 0
    end

    test "show displays bucket details" do
      get sys_admin_bucket_path(buckets(:default))

      assert_response :success
      assert_select "h1", buckets(:default).name
      assert_select ".bucket-detail__term", "Recordings"
      assert_select ".bucket-detail__description", "0 recordings"
      assert_select "a[href='#{edit_sys_admin_bucket_path(buckets(:default))}']", "Edit"
      assert_select "form[action='#{bucket_switch_path(buckets(:default))}'] button", "Switch"
    end

    test "new renders form" do
      get new_sys_admin_bucket_path

      assert_response :success
      assert_select "h1", "New Bucket"
      assert_select "form"
    end

    test "create adds bucket" do
      assert_difference -> { Bucket.count }, 1 do
        post sys_admin_buckets_path, params: { bucket: { name: "Editorial" } }
      end

      assert_redirected_to sys_admin_buckets_path
      assert_equal "Editorial", Bucket.order(:created_at).last.name
    end

    test "create renders validation errors" do
      assert_no_difference -> { Bucket.count } do
        post sys_admin_buckets_path, params: { bucket: { name: buckets(:default).name } }
      end

      assert_response :unprocessable_entity
      assert_select ".form-errors"
    end

    test "edit renders form" do
      get edit_sys_admin_bucket_path(buckets(:default))

      assert_response :success
      assert_select "h1", "Edit Bucket"
      assert_select "input[name='bucket[name]'][value='#{buckets(:default).name}']"
    end

    test "update changes bucket" do
      patch sys_admin_bucket_path(buckets(:default)), params: { bucket: { name: "Updated Bucket" } }

      assert_redirected_to sys_admin_buckets_path
      assert_equal "Updated Bucket", buckets(:default).reload.name
    end

    test "update renders validation errors" do
      other_bucket = Bucket.create!(name: "Other Bucket")

      patch sys_admin_bucket_path(other_bucket), params: { bucket: { name: buckets(:default).name } }

      assert_response :unprocessable_entity
      assert_select ".form-errors"
      assert_equal "Other Bucket", other_bucket.reload.name
    end

    test "guests are redirected to sign in" do
      sign_out

      get sys_admin_buckets_path

      assert_redirected_to new_session_path
    end
  end
end
