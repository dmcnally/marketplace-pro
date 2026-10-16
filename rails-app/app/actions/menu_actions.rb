class MenuActions < ActionsBase
  def archives_link
    view.link_to "Archived menus", view.admin_archived_menus_path, class: "btn btn--secondary" if policy.can_create?
  end

  def archive_link_for(menu)
    view.link_to "Archive menu", view.new_admin_menu_archive_path(menu), class: "btn btn--secondary" if policy.can_archive?(menu)
  end

  def archive_button_for(menu)
    return unless policy.can_archive?(menu)

    view.button_to "Archive menu", view.admin_menu_archive_path(menu), params: { revision: menu.draft_revision }, class: "btn btn--secondary"
  end

  def restore_button_for(menu)
    return unless policy.can_restore?(menu)

    view.button_to "Restore menu", view.admin_menu_archive_path(menu), method: :delete, params: { revision: menu.draft_revision }, class: "btn btn--secondary"
  end

  def publication_link_for(menu)
    view.link_to "Review & publish", view.new_admin_menu_publication_path(menu), class: "btn btn--primary" if policy.can_publish?(menu)
  end

  def unpublish_link_for(menu)
    view.link_to "Unpublish menu", view.new_admin_menu_publication_path(menu, intent: "unpublish"), class: "btn btn--secondary" if policy.can_unpublish?(menu)
  end

  def revert_link_for(menu)
    view.link_to "Revert all", view.new_admin_menu_reversion_path(menu), class: "btn btn--secondary" if policy.can_revert?(menu)
  end

  def publish_button_for(publication)
    return unless policy.can_publish?(publication.recording) && publication.blockers.empty?

    view.button_to "Publish menu", view.admin_menu_publication_path(publication.recording), params: { review_token: publication.review_token }, class: "btn btn--primary"
  end

  def unpublish_button_for(publication)
    return unless policy.can_unpublish?(publication.recording)

    view.button_to "Unpublish menu", view.admin_menu_publication_path(publication.recording), method: :delete, params: { review_token: publication.review_token }, class: "btn btn--primary"
  end

  def revert_button_for(publication)
    return unless policy.can_revert?(publication.recording)

    view.button_to "Revert all", view.admin_menu_reversion_path(publication.recording), params: { review_token: publication.review_token }, class: "btn btn--primary"
  end

  def new_link
    view.link_to "Add menu", view.new_admin_menu_path, class: "btn btn--primary" if policy.can_create?
  end

  def edit_link_for(menu)
    view.link_to "Edit menu", view.edit_admin_menu_path(menu), class: "btn btn--secondary" if policy.can_edit?(menu)
  end

  def history_link_for(menu)
    view.link_to "History", view.admin_menu_path(menu), class: "btn btn--secondary" if policy.can_view?(menu)
  end

  def preview_link_for(menu)
    view.link_to "Preview", view.admin_menu_preview_path(menu), class: "btn btn--secondary" if policy.can_view?(menu)
  end

  def form_for(draft)
    return unless draft.recording ? policy.can_edit?(draft.recording) : policy.can_create?

    view.render "menus/form", draft: draft
  end

  def new_section_link_for(menu)
    view.link_to "Add section", view.new_admin_menu_section_path(menu), class: "btn btn--secondary" if policy.can_edit?(menu)
  end

  def edit_section_link_for(menu, section)
    return unless policy.can_edit?(menu) && section.parent_id == menu.id

    view.link_to "Edit section", view.edit_admin_menu_section_path(menu, section), class: "btn btn--secondary"
  end

  def remove_section_button_for(menu, section)
    return unless policy.can_edit?(menu) && section.parent_id == menu.id

    view.button_to "Remove section", view.admin_menu_section_path(menu, section), method: :delete, params: { revision: menu.draft_revision }, class: "btn btn--secondary"
  end

  def section_form_for(draft)
    view.render "menu_sections/form", draft: draft if policy.can_edit?(draft.menu)
  end

  def section_order_form_for(menu)
    view.render "menus/section_order", menu: menu, sections: Menu::Structure.new(menu).sections if policy.can_edit?(menu)
  end

  def product_order_form_for(menu, section)
    return unless policy.can_edit?(menu) && section.parent_id == menu.id

    view.render "menu_sections/product_order", menu: menu, section: section, products: bucket.recordings.products.where(id: section.recordable.product_ids).includes(:recordable).index_by(&:id)
  end

  private

  def policy
    @policy ||= MenuPolicy.new(person: person, bucket: bucket)
  end
end
