class ProductActions < ActionsBase
  def allergen_warning
    return unless policy.can_create?

    render_allergen_warning(allergen_warnings.entries)
  end

  def allergen_warning_for(recording)
    return unless policy.can_view?(recording)

    render_allergen_warning(allergen_warnings.entries.select { |entry| entry[:recording].id == recording.id })
  end

  def copy_link_for(recording)
    view.link_to "Copy product", view.new_admin_product_copy_path(recording), class: "btn btn--secondary" if policy.can_copy?(recording)
  end

  def copy_form_for(copy)
    view.render "products/copies/form", copy: copy if policy.can_copy?(copy.source)
  end

  def archives_link
    view.link_to "Archived products & variants", view.admin_archived_products_path, class: "btn btn--secondary" if policy.can_create?
  end

  def archive_link_for(recording)
    view.link_to "Archive product", view.new_admin_product_archive_path(recording), class: "btn btn--secondary" if policy.can_archive?(recording)
  end

  def archive_button_for(recording)
    return unless policy.can_archive?(recording)

    view.button_to "Archive product", view.admin_product_archive_path(recording), params: { revision: recording.draft_revision }, class: "btn btn--secondary"
  end

  def restore_button_for(recording)
    return unless policy.can_restore?(recording)

    view.button_to "Restore product", view.admin_product_archive_path(recording), method: :delete, params: { revision: recording.draft_revision }, class: "btn btn--secondary"
  end

  def archive_variant_link_for(product, variant)
    return unless policy.can_archive_variant?(product, variant)

    view.link_to "Archive variant", view.new_admin_product_variant_archive_path(product, variant), class: "btn btn--secondary"
  end

  def archive_variant_button_for(product, variant)
    return unless policy.can_archive_variant?(product, variant)

    view.button_to "Archive variant", view.admin_product_variant_archive_path(product, variant), params: { revision: variant.draft_revision }, class: "btn btn--secondary"
  end

  def restore_variant_button_for(product, variant)
    return unless policy.can_restore_variant?(product, variant)

    view.button_to "Restore variant", view.admin_product_variant_archive_path(product, variant), method: :delete, params: { revision: variant.draft_revision }, class: "btn btn--secondary"
  end

  def revert_link_for(recording)
    return unless policy.can_revert?(recording)

    view.link_to "Revert all changes", view.new_admin_product_reversion_path(recording), class: "btn btn--secondary"
  end

  def revert_button_for(publication)
    return unless policy.can_revert?(publication.recording)

    view.button_to "Revert all", view.admin_product_reversion_path(publication.recording), params: { review_token: publication.review_token }, class: "btn btn--primary"
  end

  def publication_link_for(recording)
    return unless policy.can_publish?(recording)

    view.link_to "Review publication", view.new_admin_product_publication_path(recording), class: "btn btn--primary"
  end

  def publish_button_for(publication)
    return unless policy.can_publish?(publication.recording) && publication.blockers.empty?

    view.button_to "Publish product", view.admin_product_publication_path(publication.recording), params: { review_token: publication.review_token }, class: "btn btn--primary"
  end

  def unpublish_button_for(publication)
    return unless policy.can_unpublish?(publication.recording)

    view.button_to "Unpublish product", view.admin_product_publication_path(publication.recording), method: :delete, params: { review_token: publication.review_token }, class: "btn btn--secondary"
  end

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

  def allergen_warnings
    @allergen_warnings ||= Catalogue::AllergenWarnings.new(bucket)
  end

  def render_allergen_warning(entries)
    view.render "catalogue/allergen_warning", entries: entries, menu_name: allergen_warnings.menu_name if entries.any?
  end

  def policy
    @policy ||= ProductPolicy.new(person: person, bucket: bucket)
  end
end
