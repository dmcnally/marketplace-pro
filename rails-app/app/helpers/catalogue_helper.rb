module CatalogueHelper
  def availability_actions
    @availability_actions ||= AvailabilityActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def catalogue_price(row)
    return "No active variants" unless row[:minimum_price]

    [ ("From" if row[:variant_count] > 1), number_with_precision(row[:minimum_price], precision: 2), Current.bucket.currency ].compact.join(" ")
  end

  def catalogue_history_value(event, field, value)
    return value.presence || "Empty" unless %w[category_ids allergen_ids variant_order section_order product_ids].include?(field)
    return "None" if value.blank?

    records = event.bucket.recordings.where(id: value).index_by(&:id)
    value.map { |id| records[id]&.subject_at(event)&.name || "Record #{id}" }.join(", ")
  end

  def catalogue_availability_change(event)
    return unless event.action == "availability_changed"

    details = event.details.index_by(&:key)
    from = details["from"]&.value
    to = details["to"]&.value
    labels = { "available" => "Available", "unavailable" => "Sold out" }
    transition = "#{labels.fetch(from, "Unknown")} → #{labels.fetch(to, "Unknown")}"
    [ transition, details["reason"]&.value.presence ].compact.join(" · ")
  end

  def catalogue_publication_value(field, value)
    return "Empty" if value.blank?
    return "#{number_with_precision(value, precision: 2)} #{Current.bucket.currency}" if field.end_with?(" · Price")
    return value unless field == "Image" || field.end_with?(" · Image")

    blob = ActiveStorage::Blob.find_by(id: value)
    blob ? link_to(blob.filename.to_s, rails_blob_path(blob)) : "Image no longer available"
  end

  def catalogue_menu_transition(event)
    return unless event.subject_type == "Menu"

    details = event.details.index_by(&:key)
    key, prefix = case event.action
    when "published" then [ "replaced_menu", "Replaced" ]
    when "unpublished" then [ "replaced_by_menu", "Replaced by" ]
    else return
    end
    id = details["#{key}_id"]&.value
    return details["reason"]&.value if id.blank?
    return if id.to_i == event.eventable_id

    menu = event.bucket.recordings.menus.find_by(id: id)
    return "#{prefix} an unavailable menu." unless menu

    name = details["#{key}_name"]&.value.presence || menu.subject_at(event)&.name || "an earlier menu"
    "#{prefix} #{name}."
  end

  def product_actions
    @product_actions ||= ProductActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

  def menu_actions
    @menu_actions ||= MenuActions.new(view: self, person: Current.person, bucket: Current.bucket)
  end

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
