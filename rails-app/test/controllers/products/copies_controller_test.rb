require "test_helper"
require_relative "../../test_helpers/catalogue_test_helper"

class Products::CopiesControllerTest < ActionDispatch::IntegrationTest
  include CatalogueTestHelper

  setup do
    @membership = Membership.create!(person: users(:two).person, bucket: Current.bucket, role: :editor)
    sign_in_as users(:two)
    @product = create_catalogue_product
  end

  test "form creates an unpublished copy and redirects to its editor" do
    get new_admin_product_copy_path(@product)
    assert_response :success
    assert_select "input[name='product_copy[name]'][value='Wings copy']"
    revision = css_select("input[name=revision]").sole["value"]
    assert_difference "Recording.products.count", 1 do
      post admin_product_copy_path(@product), params: { product_copy: { name: "New wings" }, revision: revision }
    end
    copy = Recording.products.order(:id).last
    assert_redirected_to edit_admin_product_path(copy)
    follow_redirect!
    assert_select "h1", "New wings"
    assert_select "p", /Never published/
    assert_equal users(:two).person, copy.events.find_by!(action: "copied").person
  end

  test "invalid copies render errors and stale submissions are rejected" do
    assert_no_difference "Recording.count" do
      post admin_product_copy_path(@product), params: { product_copy: { name: "" }, revision: @product.draft_revision }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", /Name can't be blank/
      post admin_product_copy_path(@product), params: { product_copy: { name: "Copy" }, revision: "stale" }
      assert_response :conflict
    end
  end

  test "viewer foreign bucket and archived source access is rejected" do
    foreign = create_catalogue_product(bucket: Bucket.create!(name: "Foreign"))
    get new_admin_product_copy_path(foreign)
    assert_response :not_found
    post admin_product_copy_path(foreign)
    assert_response :not_found
    @membership.update!(role: :viewer)
    get new_admin_product_copy_path(@product)
    assert_response :forbidden
    post admin_product_copy_path(@product)
    assert_response :forbidden
    @membership.update!(role: :editor)
    @product.archive_content!(revision: @product.reload.draft_revision)
    get new_admin_product_copy_path(@product)
    assert_response :forbidden
    post admin_product_copy_path(@product)
    assert_response :forbidden
  end
end
