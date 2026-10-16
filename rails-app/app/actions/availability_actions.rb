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
    navigation_link("Overview", view.overview_path, "catalogue/overviews") if policy.can_view?
  end

  def orders_link
    navigation_link("Orders", view.orders_path, "orders") if OrderPolicy.new(person: person, bucket: bucket).can_view?
  end

  private

  def navigation_link(label, path, controller)
    active = view.controller_path == controller
    view.link_to label, path, class: [ "catalogue__nav-link", ("catalogue__nav-link--active" if active) ], aria: { current: ("page" if active) }
  end

  def policy
    @policy ||= AvailabilityPolicy.new(availability: Catalogue::Availability.new(person: person, bucket: bucket))
  end
end
