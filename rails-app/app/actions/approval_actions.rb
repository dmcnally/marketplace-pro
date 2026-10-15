class ApprovalActions < ActionsBase
  def approve_button_for(subject)
    return unless subject.is_a?(Approvable)
    return unless person_allowed_to?(:approve, subject)
    return if subject.approved?
    return approving_button_for(subject) if subject.approval_in_progress?
    return unless subject.approvable?

    view.button_to "Approve",
      view.approval_path,
      params: {
        approvable: subject.to_sgid(for: "approval", expires_in: nil)
      },
      form: {
        id: view.dom_id(subject, :approval_button),
        data: { turbo_stream: true }
      },
      data: { turbo_submits_with: "Approving" },
      class: "btn btn--primary"
  end

  private

  def approving_button_for(subject)
    view.button_tag "Approving",
      id: view.dom_id(subject, :approval_button),
      type: "button",
      disabled: true,
      class: "btn btn--primary btn--pending"
  end
end
