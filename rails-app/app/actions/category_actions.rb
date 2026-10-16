class CategoryActions < ActionsBase
  def new_link
    return unless policy.can_create?

    view.link_to "Add category", view.new_admin_category_path, class: "btn btn--primary"
  end

  def edit_link_for(recording)
    return unless policy.can_edit?(recording)

    view.link_to "Edit category", view.edit_admin_category_path(recording), class: "btn btn--secondary"
  end

  def history_link_for(recording)
    return unless policy.can_view?(recording)

    view.link_to "History", view.admin_category_path(recording), class: "btn btn--secondary"
  end

  def archive_button_for(recording)
    return unless policy.can_archive?(recording)

    view.button_to "Archive category", view.admin_category_archive_path(recording), params: { revision: recording.draft_revision }, class: "btn btn--danger", data: { turbo_confirm: "Archive this category? Existing assignments and history will be preserved." }
  end

  def restore_button_for(recording)
    return unless policy.can_restore?(recording)

    view.button_to "Restore category", view.admin_category_archive_path(recording), method: :delete, params: { revision: recording.draft_revision }, class: "btn btn--secondary"
  end

  def form_for(recording)
    return unless recording.new_record? ? policy.can_create? : policy.can_edit?(recording)

    view.render "categories/form", recording: recording
  end

  private

  def policy
    @policy ||= CategoryPolicy.new(person: person, bucket: bucket)
  end
end
