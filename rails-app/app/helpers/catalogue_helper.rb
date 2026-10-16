module CatalogueHelper
  def allergen_actions
    @allergen_actions ||= AllergenActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def catalogue_navigation_actions
    @catalogue_navigation_actions ||= CatalogueNavigationActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def category_actions
    @category_actions ||= CategoryActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end
end
