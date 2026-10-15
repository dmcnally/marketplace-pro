require "test_helper"

class InvitationActionsTest < ActiveSupport::TestCase
  test "accept button renders" do
    actions = InvitationActions.new(view: FakeInvitationView.new, person: Current.person, bucket: Current.bucket)

    assert_equal(
      {
        label: "Accept Invitation",
        path: "/invitations/raw-token/accept",
        options: { class: "btn btn--primary" }
      },
      actions.accept_button_for("raw-token")
    )
  end

  class FakeInvitationView
    def button_to(label, path, options = {})
      { label:, path:, options: }
    end

    def accept_invitation_path(token)
      "/invitations/#{token}/accept"
    end
  end
end
