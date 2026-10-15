require "test_helper"

module Admin
  class InvitationsControllerTest < ActionDispatch::IntegrationTest
    test "index allows bucket admins" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      MembershipInvite.create!(
        bucket: buckets(:default),
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "new@example.com",
        role: :editor
      )

      get admin_invitations_path

      assert_response :success
      assert_select "h1", "Invitations"
      assert_select ".management-sidebar__link--active", "Invitations"
      assert_select "a[href='#{new_admin_invitation_path}']", "New Invitation"
      assert_select ".invitation-list__name", "fname lname"
      assert_select ".invitation-list__email", "new@example.com"
      assert_select ".invitation-list__role", "Editor"
      assert_select "form[action='#{admin_invitation_path(MembershipInvite.last)}']" do
        assert_select "button", "Cancel"
      end
    end

    test "index splits invitations into sent accepted and expired" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      sent_invitation = MembershipInvite.create!(
        bucket: buckets(:default),
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "sent@example.com",
        role: :viewer
      )
      accepted_invitation = MembershipInvite.create!(
        bucket: buckets(:default),
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "accepted@example.com",
        role: :editor,
        accepted_at: Time.current,
        accepted_by: user.person
      )
      old_accepted_invitation = MembershipInvite.create!(
        bucket: buckets(:default),
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "old-accepted@example.com",
        role: :editor,
        accepted_at: 31.days.ago,
        accepted_by: user.person
      )
      expired_invitation = MembershipInvite.create!(
        bucket: buckets(:default),
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "expired@example.com",
        role: :admin,
        expires_at: 1.day.ago
      )

      get admin_invitations_path

      assert_response :success
      assert_invitation_section "Sent", sent_invitation.email_address
      assert_invitation_section "Recently accepted", accepted_invitation.email_address
      assert_invitation_section_excludes "Recently accepted", old_accepted_invitation.email_address
      assert_invitation_section "Expired", expired_invitation.email_address
    end

    test "new allows bucket admins" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      get new_admin_invitation_path

      assert_response :success
      assert_select "h1", "New Invitation"
      assert_select "form[action='#{admin_invitations_path}']"
    end

    test "create creates invitation for current bucket" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      assert_enqueued_emails 1 do
        assert_difference -> { MembershipInvite.count }, 1 do
          post admin_invitations_path, params: {
            membership_invite: {
              first_name: "fname",
              last_name: "lname",
              email_address: " Invited@Example.com ",
              role: "editor"
            }
          }
        end
      end

      invitation = MembershipInvite.last
      assert_redirected_to admin_invitations_path
      assert_equal buckets(:default), invitation.bucket
      assert_equal user.person, invitation.invited_by
      assert_equal "invited@example.com", invitation.email_address
      assert_equal "editor", invitation.role
      assert_predicate invitation.token_digest, :present?
      assert_predicate invitation.expires_at, :future?
    end

    test "create rejects invalid invitation role" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      assert_enqueued_emails 0 do
        assert_no_difference -> { MembershipInvite.count } do
          post admin_invitations_path, params: {
            membership_invite: {
              first_name: "fname",
              last_name: "lname",
              email_address: "invited@example.com",
              role: "owner"
            }
          }
        end
      end

      assert_response :unprocessable_entity
      assert_select ".form-errors"
    end

    test "create does not send email for invalid invitation" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      assert_enqueued_emails 0 do
        assert_no_difference -> { MembershipInvite.count } do
          post admin_invitations_path, params: {
            membership_invite: {
              email_address: "",
              role: "editor"
            }
          }
        end
      end

      assert_response :unprocessable_entity
      assert_select ".form-errors"
    end

    test "create rejects invalid invitation" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user

      assert_no_difference -> { MembershipInvite.count } do
        post admin_invitations_path, params: {
          membership_invite: {
            email_address: "",
            role: "editor"
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select ".form-errors"
    end

    test "destroy cancels sent invitation" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user
      invitation = MembershipInvite.create!(
        bucket: buckets(:default),
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "cancel@example.com",
        role: :viewer
      )

      assert_no_difference -> { MembershipInvite.count } do
        delete admin_invitation_path(invitation)
      end

      assert_redirected_to admin_invitations_path
      assert_predicate invitation.reload, :revoked?
    end

    test "destroy does not cancel accepted invitation" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user
      invitation = MembershipInvite.create!(
        bucket: buckets(:default),
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "accepted-cancel@example.com",
        role: :viewer,
        accepted_at: Time.current,
        accepted_by: user.person
      )

      delete admin_invitation_path(invitation)

      assert_redirected_to admin_invitations_path
      assert_nil invitation.reload.revoked_at
    end

    test "destroy scopes invitation to current bucket" do
      user = users(:two)
      other_bucket = Bucket.create!(name: "Other")
      Membership.create!(person: user.person, bucket: buckets(:default), role: :admin)
      sign_in_as user
      invitation = MembershipInvite.create!(
        bucket: other_bucket,
        invited_by: user.person,
        first_name: "fname",
        last_name: "lname",
        email_address: "other@example.com",
        role: :viewer
      )

      delete admin_invitation_path(invitation)

      assert_response :not_found
      assert_nil invitation.reload.revoked_at
    end

    test "index redirects guests to sign in" do
      get admin_invitations_path

      assert_redirected_to new_session_path
    end

    test "index forbids signed-in non-admins" do
      user = users(:two)
      Membership.create!(person: user.person, bucket: buckets(:default), role: :viewer)
      sign_in_as user

      get admin_invitations_path

      assert_response :forbidden
    end

    private

    def assert_invitation_section(title, email_address)
      assert_select ".invitation-section" do |sections|
        section = sections.find { |node| node.css(".invitation-section__title").text == title }

        assert section, "Expected #{title.inspect} invitation section"
        assert_includes section.text, email_address
      end
    end

    def assert_invitation_section_excludes(title, email_address)
      assert_select ".invitation-section" do |sections|
        section = sections.find { |node| node.css(".invitation-section__title").text == title }

        assert section, "Expected #{title.inspect} invitation section"
        assert_not_includes section.text, email_address
      end
    end
  end
end
