class InvitationActions < ActionsBase
  def accept_button_for(token)
    view.button_to "Accept Invitation", view.accept_invitation_path(token), class: "btn btn--primary"
  end
end
