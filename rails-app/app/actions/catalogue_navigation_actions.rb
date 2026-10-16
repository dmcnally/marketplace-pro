class CatalogueNavigationActions < ActionsBase
  def links
    links = []
    links << link("Products", view.admin_products_path, "products") if ProductPolicy.new(person: person, bucket: bucket).can_create?
    links << link("Categories", view.admin_categories_path, "categories") if CategoryPolicy.new(person: person, bucket: bucket).can_create?
    links << link("Allergens", view.admin_allergens_path, "allergens") if AllergenPolicy.new(person: person, bucket: bucket).can_create?
    links << link("Back to workspace", view.root_path, nil)
    view.safe_join(links)
  end

  private

  def link(label, path, controller)
    active = view.controller_path.split("/").first == controller
    view.link_to label, path, class: [ "catalogue__nav-link", ("catalogue__nav-link--active" if active) ], aria: { current: ("page" if active) }
  end
end
