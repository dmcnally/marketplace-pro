class Admin::SidebarActions < ActionsBase
  def dashboard_link
    view.link_to "Dashboard",
                 view.admin_root_path,
                 class: [
                   "management-sidebar__link",
                   ("management-sidebar__link--active" if dashboard_active?)
                 ]
  end

  def members_link
    view.link_to "Members",
                 view.admin_members_path,
                 class: [
                   "management-sidebar__link",
                   ("management-sidebar__link--active" if view.controller_path == "admin/members")
                 ]
  end

  def invitations_link
    view.link_to "Invitations",
                 view.admin_invitations_path,
                 class: [
                   "management-sidebar__link",
                   ("management-sidebar__link--active" if view.controller_path == "admin/invitations")
                 ]
  end

  def imports_link
    view.link_to "Imports", view.admin_csv_imports_path,
                 class: [ "management-sidebar__link", ("management-sidebar__link--active" if view.controller_path == "admin/csv_imports") ]
  end

  private

  def dashboard_active?
    view.current_page?(view.admin_root_path) || view.current_page?(view.admin_dashboard_path)
  end
end
