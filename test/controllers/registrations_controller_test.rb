require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new renders signup form" do
    get new_registration_path

    assert_response :success
    assert_select "h1", "Create account"
    assert_select "form[action='#{registration_path}']"
  end

  test "new prepopulates signup fields from pending invitation" do
    invitation = membership_invite(
      first_name: "Invited",
      last_name: "Person",
      email_address: "invited-person@example.com"
    )

    post accept_invitation_path(invitation.token)
    get new_registration_path

    assert_select "input[name='user_registration[first_name]'][value='Invited']"
    assert_select "input[name='user_registration[last_name]'][value='Person']"
    assert_select "input[name='user_registration[email_address]'][value='invited-person@example.com']"
  end

  test "create signs up and redirects to no bucket without pending invitation" do
    assert_difference -> { User.count }, 1 do
      assert_difference -> { Person.count }, 1 do
        post registration_path, params: registration_params(email_address: "new@example.com")
      end
    end

    user = User.find_by!(email_address: "new@example.com")
    assert_redirected_to no_bucket_path
    assert cookies[:session_id]
    assert_equal "New User", user.person.person_card.name
  end

  test "create signs up and returns to pending invitation" do
    invitation = membership_invite

    post accept_invitation_path(invitation.token)
    get new_registration_path

    assert_difference -> { User.count }, 1 do
      assert_difference -> { Person.count }, 1 do
        assert_no_difference -> { Membership.count } do
          post registration_path, params: registration_params(email_address: "new-invite@example.com")
        end
      end
    end

    user = User.find_by!(email_address: "new-invite@example.com")
    assert_redirected_to invitation_path(invitation.token)
    assert cookies[:session_id]
    assert_equal buckets(:identity), user.person.recording.bucket
    assert_nil invitation.reload.accepted_at
  end

  test "new signup can accept invitation after returning to invitation page" do
    invitation = membership_invite(role: :editor)

    post accept_invitation_path(invitation.token)
    post registration_path, params: registration_params(email_address: "accepting@example.com")

    assert_difference -> { Membership.count }, 1 do
      post accept_invitation_path(invitation.token)
    end

    user = User.find_by!(email_address: "accepting@example.com")
    membership = Membership.last
    assert_redirected_to root_path
    assert_equal user.person, membership.person
    assert_equal invitation.bucket, membership.bucket
    assert_predicate membership, :editor?
    assert_equal user.person, invitation.reload.accepted_by
  end

  test "create renders errors for invalid signup" do
    assert_no_difference -> { User.count } do
      post registration_path, params: registration_params(email_address: users(:one).email_address)
    end

    assert_response :unprocessable_entity
    assert_select ".login__alert", /Email address has already been taken/
  end

  private

  def registration_params(email_address:)
    {
      user_registration: {
        first_name: "New",
        last_name: "User",
        email_address:,
        password: "password",
        password_confirmation: "password"
      }
    }
  end

  def membership_invite(attributes = {})
    MembershipInvite.create!(
      {
        bucket: buckets(:default),
        invited_by: people(:one),
        first_name: "fname",
        last_name: "lname",
        email_address: "invited-#{SecureRandom.hex(4)}@example.com",
        role: :viewer
      }.merge(attributes)
    )
  end
end
