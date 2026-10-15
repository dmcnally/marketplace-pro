class MembershipInvitesMailer < ApplicationMailer
  def invite(invitation, token)
    @invitation = invitation
    @token = token

    mail subject: "You have been invited to #{invitation.bucket.name}", to: invitation.email_address
  end
end
