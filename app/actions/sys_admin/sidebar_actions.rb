class SysAdmin::SidebarActions < ActionsBase
  def dashboard_link
    view.link_to "Dashboard",
                 view.sys_admin_root_path,
                 class: [
                   "management-sidebar__link",
                   ("management-sidebar__link--active" if dashboard_active?)
                 ]
  end

  def buckets_link
    view.link_to "Buckets",
                 view.sys_admin_buckets_path,
                 class: [
                   "management-sidebar__link",
                   ("management-sidebar__link--active" if view.controller_path == "sys_admin/buckets")
                 ]
  end

  def users_link
    view.link_to "Users",
                 view.sys_admin_users_path,
                 class: [
                   "management-sidebar__link",
                   ("management-sidebar__link--active" if view.controller_path == "sys_admin/users")
                 ]
  end

  private

  def dashboard_active?
    view.current_page?(view.sys_admin_root_path) || view.current_page?(view.sys_admin_dashboard_path)
  end
end
