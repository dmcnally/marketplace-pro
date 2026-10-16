require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  test "orders is a read-only deferred destination for each membership role" do
    membership = Membership.create!(person: users(:two).person, bucket: Current.bucket, role: :viewer)
    sign_in_as users(:two)
    %i[viewer editor admin].each do |role|
      membership.update!(role: role)
      get orders_path
      assert_response :success
      assert_select "h1", "Orders"
      assert_select "h2", "Orders workflow is deferred"
      assert_select "nav[aria-label=Main] a" do |links|
        expected = [ "Overview", "Orders" ]
        expected += [ "Products", "Categories", "Allergens", "Menus" ] unless role == :viewer
        expected << "Admin" if role == :admin
        assert_equal expected, links.map(&:text)
      end
      assert_select "nav a[aria-current=page]", text: "Orders", count: 1
      assert_select "main form", count: 0
    end
  end

  test "guests must sign in and revoked membership cannot view orders" do
    get orders_path
    assert_redirected_to new_session_path
    membership = Membership.create!(person: users(:two).person, bucket: Current.bucket, role: :viewer)
    sign_in_as users(:two)
    membership.destroy!
    get orders_path
    assert_redirected_to no_bucket_path
  end
end
