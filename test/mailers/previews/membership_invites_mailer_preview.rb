class MembershipInvitesMailerPreview < ActionMailer::Preview
  def invite
    MembershipInvitesMailer.invite(MembershipInvite.first || preview_invitation, "preview-token")
  end

  private

  def preview_invitation
    MembershipInvite.new(
      bucket: Bucket.content.first || Bucket.first,
      invited_by: Person.first,
      email_address: "invited@example.com",
      role: :viewer,
      expires_at: MembershipInvite::DEFAULT_EXPIRES_IN.from_now
    )
  end
end
