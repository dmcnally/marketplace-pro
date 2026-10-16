class ProductActions < ActionsBase
  def new_link
    view.link_to("Add product", view.new_admin_product_path, class: "btn btn--primary") if policy.can_create?
  end

  def edit_link_for(recording)
    view.link_to("Edit product", view.edit_admin_product_path(recording), class: "btn btn--secondary") if policy.can_edit?(recording)
  end

  def history_link_for(recording)
    view.link_to("History", view.admin_product_path(recording), class: "btn btn--secondary") if policy.can_view?(recording)
  end

  def form_for(draft)
    return unless draft.recording ? policy.can_edit?(draft.recording) : policy.can_create?

    view.render "products/form", draft: draft
  end

  def variant_link_for(product, variant)
    return unless policy.can_edit?(product) && variant.parent_id == product.id && variant.kept?

    view.link_to "Edit variant", view.edit_admin_product_variant_path(product, variant), class: "btn btn--secondary"
  end

  def new_variant_link_for(product)
    return unless policy.can_edit?(product)

    view.link_to "Add variant from", view.new_admin_product_variant_path(product), class: "btn btn--secondary"
  end

  def variant_form_for(draft)
    return unless policy.can_edit?(draft.product)

    view.render "variants/form", draft: draft
  end

  def ordering_form_for(draft)
    return unless policy.can_edit?(draft.recording)

    view.render "products/variant_order", draft: draft
  end

  def allergen_form_for(product)
    return unless policy.can_edit?(product)

    view.render "products/allergen_assignment", product: product, allergens: bucket.recordings.allergens.includes(:recordable)
  end

  private

  def policy
    @policy ||= ProductPolicy.new(person: person, bucket: bucket)
  end
end
