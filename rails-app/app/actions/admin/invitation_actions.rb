class Admin::InvitationActions < ActionsBase
  def new_link(label: "New Invitation")
    view.link_to label, view.new_admin_invitation_path, class: "btn btn--primary"
  end

  def index_back_link
    view.link_to "&larr; Back to Invitations".html_safe,
                 view.admin_invitations_path,
                 class: "back-link"
  end

  def form_cancel_link
    view.link_to "Cancel", view.admin_invitations_path, class: "btn btn--secondary"
  end

  def cancel_button_for(invitation)
    view.button_to "Cancel",
                   view.admin_invitation_path(invitation),
                   method: :delete,
                   class: "btn btn--danger",
                   form_class: "invitation-list__action-form",
                   form: { data: { turbo_confirm: "Cancel invitation for #{invitation.email_address}?" } }
  end
end
