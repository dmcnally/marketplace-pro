require "test_helper"

class Admin::SidebarActionsTest < ActiveSupport::TestCase
  setup do
    @view = FakeAdminSidebarView.new
  end

  test "dashboard link renders inactive" do
    actions = Admin::SidebarActions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_equal(
      {
        label: "Dashboard",
        path: "/admin",
        options: { class: [ "management-sidebar__link", nil ] }
      },
      actions.dashboard_link
    )
  end

  test "dashboard link renders active" do
    @view.current_path = "/admin/dashboard"
    actions = Admin::SidebarActions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_equal(
      {
        label: "Dashboard",
        path: "/admin",
        options: { class: [ "management-sidebar__link", "management-sidebar__link--active" ] }
      },
      actions.dashboard_link
    )
  end

  test "members link renders active for members controller" do
    @view.controller_path = "admin/members"
    actions = Admin::SidebarActions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_equal(
      {
        label: "Members",
        path: "/admin/members",
        options: { class: [ "management-sidebar__link", "management-sidebar__link--active" ] }
      },
      actions.members_link
    )
  end

  test "invitations link renders active for invitations controller" do
    @view.controller_path = "admin/invitations"
    actions = Admin::SidebarActions.new(view: @view, person: Current.person, bucket: Current.bucket)

    assert_equal(
      {
        label: "Invitations",
        path: "/admin/invitations",
        options: { class: [ "management-sidebar__link", "management-sidebar__link--active" ] }
      },
      actions.invitations_link
    )
  end

  class FakeAdminSidebarView
    attr_accessor :controller_path, :current_path

    def link_to(label, path, options = {})
      { label:, path:, options: }
    end

    def current_page?(path)
      current_path == path
    end

    def admin_root_path
      "/admin"
    end

    def admin_dashboard_path
      "/admin/dashboard"
    end

    def admin_members_path
      "/admin/members"
    end

    def admin_invitations_path
      "/admin/invitations"
    end
  end
end
