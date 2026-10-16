class AvailabilityActions < ActionsBase
  def variant_button_for(variant)
    return unless policy.can_change_variant?(variant[:recording])

    view.button_to variant[:available] ? "Mark sold out" : "Make available", view.availability_path,
      method: variant[:available] ? :delete : :post, params: { recording_id: variant[:recording].id }, class: "btn btn--secondary"
  end

  def product_buttons_for(product)
    return unless policy.can_change_product?(product[:recording]) && product[:variants].many?

    view.safe_join([ [ "All available", :post ], [ "All sold out", :delete ] ].map do |label, method|
      view.button_to label, view.availability_path, method: method, params: { recording_id: product[:recording].id }, class: "btn btn--secondary"
    end)
  end

  def overview_link
    view.link_to "Overview", view.overview_path, class: "catalogue__nav-link catalogue__nav-link--active", aria: { current: "page" } if policy.can_view?
  end

  def admin_link
    view.link_to "Admin", view.admin_products_path, class: "catalogue__nav-link" if ProductPolicy.new(person: person, bucket: bucket).can_create?
  end

  private

  def policy
    @policy ||= AvailabilityPolicy.new(availability: Catalogue::Availability.new(person: person, bucket: bucket))
  end
end
