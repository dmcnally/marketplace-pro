require "test_helper"

class Admin::InvitationActionsTest < ActiveSupport::TestCase
  setup do
    @view = FakeAdminInvitationView.new
    @actions = Admin::InvitationActions.new(view: @view, person: Current.person, bucket: Current.bucket)
  end

  test "new link renders" do
    assert_equal(
      {
        label: "New Invitation",
        path: "/admin/invitations/new",
        options: { class: "btn btn--primary" }
      },
      @actions.new_link
    )
  end

  test "index back link renders" do
    assert_equal(
      {
        label: "&larr; Back to Invitations",
        path: "/admin/invitations",
        options: { class: "back-link" }
      },
      @actions.index_back_link
    )
  end

  test "form cancel link renders" do
    assert_equal(
      {
        label: "Cancel",
        path: "/admin/invitations",
        options: { class: "btn btn--secondary" }
      },
      @actions.form_cancel_link
    )
  end

  test "cancel button renders" do
    invitation = MembershipInvite.new(id: 42, email_address: "invited@example.com")

    assert_equal(
      {
        label: "Cancel",
        path: "/admin/invitations/42",
        options: {
          method: :delete,
          class: "btn btn--danger",
          form_class: "invitation-list__action-form",
          form: { data: { turbo_confirm: "Cancel invitation for invited@example.com?" } }
        }
      },
      @actions.cancel_button_for(invitation)
    )
  end

  class FakeAdminInvitationView
    def link_to(label, path, options = {})
      { label:, path:, options: }
    end

    def new_admin_invitation_path
      "/admin/invitations/new"
    end

    def admin_invitations_path
      "/admin/invitations"
    end

    def admin_invitation_path(invitation)
      "/admin/invitations/#{invitation.id}"
    end

    def button_to(label, path, options = {})
      { label:, path:, options: }
    end
  end
end
