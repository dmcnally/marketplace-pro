require "test_helper"

class ModernNavigationTest < ActionDispatch::IntegrationTest
  test "guest homepage uses workspace shell without management links" do
    get root_path

    assert_response :success
    assert_select ".management-sidebar__brand", "Marketplace"
    assert_select "nav[aria-label=Workspace]" do
      assert_select "a[href=?]", articles_path, count: 0
      assert_select "a[href=?]", admin_members_path, count: 0
      assert_select "a[href=?]", sys_admin_root_path, count: 0
    end
  end

  test "workspace admin sees catalogue in the main sidebar and user management through Admin" do
    user = users(:two)
    Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
    sign_in_as user
    get articles_path

    assert_response :success
    assert_select "nav[aria-label=Workspace]" do
      assert_select "a", text: "Articles", count: 0
      assert_select "a[href=?]", overview_path, text: "Overview"
      assert_select "a[href=?]", orders_path, text: "Orders"
      assert_select "a[href=?]", admin_products_path, text: "Products"
      assert_select "a[href=?]", admin_categories_path, text: "Categories"
      assert_select "a[href=?]", admin_allergens_path, text: "Allergens"
      assert_select "a[href=?]", admin_menus_path, text: "Menus"
      assert_select "a[href=?]", admin_root_path, text: "Admin"
      assert_select "a[href=?]", admin_members_path, count: 0
      assert_select "a[href=?]", admin_csv_imports_path, count: 0
      assert_select "a[href=?]", sys_admin_root_path, count: 0
    end
  end

  test "editors have consistent catalogue navigation without access to user administration" do
    Membership.create!(person: users(:two).person, bucket: buckets(:default), role: :editor)
    sign_in_as users(:two)

    [ overview_path, admin_products_path, admin_categories_path, admin_allergens_path, admin_menus_path ].each do |path|
      get path
      assert_response :success
      assert_select "nav[aria-label=Main] a" do |links|
        assert_equal [ "Overview", "Orders", "Products", "Categories", "Allergens", "Menus" ], links.map(&:text)
      end
      assert_select "nav a[aria-current=page]", count: 1
    end

    [ admin_root_path, admin_members_path, admin_invitations_path ].each do |path|
      get path
      assert_response :forbidden
    end
  end

  test "catalogue routes are outside the admin URL namespace" do
    assert_equal "/products", admin_products_path
    assert_equal "/categories", admin_categories_path
    assert_equal "/allergens", admin_allergens_path
    assert_equal "/menus", admin_menus_path
  end
end
