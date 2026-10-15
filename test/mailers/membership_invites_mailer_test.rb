require "test_helper"

class MembershipInvitesMailerTest < ActionMailer::TestCase
  test "invite" do
    invitation = MembershipInvite.create!(
      bucket: buckets(:default),
      invited_by: people(:one),
      first_name: "fname",
      last_name: "lname",
      email_address: "invited@example.com",
      role: :editor
    )

    mail = MembershipInvitesMailer.invite(invitation, "raw-token")

    assert_equal [ "invited@example.com" ], mail.to
    assert_equal "You have been invited to Default", mail.subject
    assert_match "Default", mail.body.encoded
    assert_match "Editor", mail.body.encoded
    assert_match "http://example.com/invitations/raw-token", mail.body.encoded
  end
end
