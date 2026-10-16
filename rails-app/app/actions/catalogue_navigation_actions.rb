class CatalogueNavigationActions < NavigationActions
  def links = workspace_links

  private

  def link_class = "catalogue__nav-link"
end
