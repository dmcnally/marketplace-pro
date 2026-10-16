class NavigationActions < ActionsBase
  def workspace_links
    links = []
    if bucket && person.viewer_of?(bucket)
      links << link("Overview", view.overview_path, "catalogue/overviews")
      links << link("Orders", view.orders_path, "orders")
    end
    if bucket
      links << link("Products", view.admin_products_path, "products") if ProductPolicy.new(person: person, bucket: bucket).can_create?
      links << link("Categories", view.admin_categories_path, "categories") if CategoryPolicy.new(person: person, bucket: bucket).can_create?
      links << link("Allergens", view.admin_allergens_path, "allergens") if AllergenPolicy.new(person: person, bucket: bucket).can_create?
      links << link("Menus", view.admin_menus_path, "menus") if MenuPolicy.new(person: person, bucket: bucket).can_create?
    end
    if bucket && person.admin_of?(bucket)
      links << link("Admin", view.admin_root_path, "admin")
    end
    if person.sys_admin?
      links << link("System admin", view.sys_admin_root_path, "sys_admin/dashboards")
    end
    view.safe_join(links)
  end

  private

  def link(label, path, controller)
    current = view.controller_path
    active = current == controller || current.start_with?("#{controller}/") ||
      (controller == "products" && current.start_with?("variants")) ||
      (controller == "menus" && current.start_with?("menu_sections"))
    view.link_to label, path, class: [ link_class, ("#{link_class}--active" if active) ], aria: { current: ("page" if active) }
  end

  def link_class = "management-sidebar__link"
end
