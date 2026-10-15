require "test_helper"

class ModernNavigationTest < ActionDispatch::IntegrationTest
  test "guest homepage uses workspace shell without management links" do
    get root_path

    assert_response :success
    assert_select ".management-sidebar__brand", "b. Blogger"
    assert_select "nav[aria-label=Workspace]" do
      assert_select "a[href=?]", articles_path, text: "Articles"
      assert_select "a[href=?]", admin_members_path, count: 0
      assert_select "a[href=?]", sys_admin_root_path, count: 0
    end
  end

  test "workspace admin can navigate from articles to members and imports" do
    user = users(:two)
    Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
    sign_in_as user
    get articles_path

    assert_response :success
    assert_select "nav[aria-label=Workspace]" do
      assert_select "a[aria-current=page]", "Articles"
      assert_select "a[href=?]", admin_members_path, text: "Members"
      assert_select "a[href=?]", admin_csv_imports_path, text: "Imports"
      assert_select "a[href=?]", sys_admin_root_path, count: 0
    end
  end
end
