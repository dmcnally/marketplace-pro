class NavigationActions < ActionsBase
  def workspace_links
    links = []
    if bucket && person.viewer_of?(bucket)
      links << link("Overview", view.overview_path, "catalogue/overviews")
      links << link("Orders", view.orders_path, "orders")
    end
    if bucket && CategoryPolicy.new(person: person, bucket: bucket).can_create?
      links << link("Admin", view.admin_products_path, "products")
    end
    if bucket && person.admin_of?(bucket)
      links << link("Members", view.admin_members_path, "admin/members")
      links << link("Invitations", view.admin_invitations_path, "admin/invitations")
      links << link("Imports", view.admin_csv_imports_path, "admin/csv_imports")
    end
    if person.sys_admin?
      links << link("System admin", view.sys_admin_root_path, "sys_admin/dashboards")
    end
    view.safe_join(links)
  end

  private

  def link(label, path, controller)
    active = view.controller_path == controller
    view.link_to label, path, class: [ "management-sidebar__link", ("management-sidebar__link--active" if active) ], aria: { current: ("page" if active) }
  end
end
