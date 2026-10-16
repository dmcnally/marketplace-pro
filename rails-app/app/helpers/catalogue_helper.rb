module CatalogueHelper
  def category_actions
    @category_actions ||= CategoryActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end
end
