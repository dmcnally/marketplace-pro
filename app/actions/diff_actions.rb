class DiffActions < ActionsBase
  def show_link_for(recording)
    return unless recording.diffable?
    return unless recording.viewable_by?(person)

    view.link_to "Compare Changes", view.recording_diff_path(recording), class: "btn btn--secondary"
  end
end
