require "test_helper"

class SysAdmin::SidebarActionsTest < ActiveSupport::TestCase
  setup do
    @view = FakeSysAdminSidebarView.new
  end

  test "dashboard link renders active for dashboard path" do
    @view.current_path = "/sys_admin/dashboard"
    actions = SysAdmin::SidebarActions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_equal(
      {
        label: "Dashboard",
        path: "/sys_admin",
        options: { class: [ "management-sidebar__link", "management-sidebar__link--active" ] }
      },
      actions.dashboard_link
    )
  end

  test "buckets link renders active for buckets controller" do
    @view.controller_path = "sys_admin/buckets"
    actions = SysAdmin::SidebarActions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_equal(
      {
        label: "Buckets",
        path: "/sys_admin/buckets",
        options: { class: [ "management-sidebar__link", "management-sidebar__link--active" ] }
      },
      actions.buckets_link
    )
  end

  test "users link renders active for users controller" do
    @view.controller_path = "sys_admin/users"
    actions = SysAdmin::SidebarActions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_equal(
      {
        label: "Users",
        path: "/sys_admin/users",
        options: { class: [ "management-sidebar__link", "management-sidebar__link--active" ] }
      },
      actions.users_link
    )
  end

  class FakeSysAdminSidebarView
    attr_accessor :controller_path, :current_path

    def link_to(label, path, options = {})
      { label:, path:, options: }
    end

    def current_page?(path)
      current_path == path
    end

    def sys_admin_root_path
      "/sys_admin"
    end

    def sys_admin_dashboard_path
      "/sys_admin/dashboard"
    end

    def sys_admin_buckets_path
      "/sys_admin/buckets"
    end

    def sys_admin_users_path
      "/sys_admin/users"
    end
  end
end
