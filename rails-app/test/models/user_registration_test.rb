require "test_helper"

class UserRegistrationTest < ActiveSupport::TestCase
  test "save creates the user identity records in the identity bucket" do
    registration = user_registration(email_address: "registered@example.com", identity_bucket: buckets(:identity))

    assert_difference -> { User.count }, 1 do
      assert_difference -> { Person.count }, 1 do
        assert_difference -> { PersonCard.count }, 1 do
          assert_difference -> { Recording.count }, 1 do
            assert registration.save
          end
        end
      end
    end

    user = registration.user
    assert_equal "registered@example.com", user.email_address
    assert_equal "New User", user.person.person_card.name
    assert_equal buckets(:identity), user.person.recording.bucket
  end

  test "active invitation bucket does not own identity records" do
    invited_bucket = Bucket.create!(name: "Invited Bucket")
    invitation = membership_invite(bucket: invited_bucket)
    registration = user_registration(
      email_address: "invited-registration@example.com",
      identity_bucket: buckets(:identity),
      invitation_token: invitation.token
    )

    assert registration.save

    assert_equal buckets(:identity), registration.user.person.recording.bucket
  end

  test "apply invitation defaults fills blank form fields" do
    invitation = membership_invite(
      first_name: "Invited",
      last_name: "Person",
      email_address: "invited-defaults@example.com"
    )
    registration = UserRegistration.new(invitation_token: invitation.token)

    registration.apply_invitation_defaults

    assert_equal "Invited", registration.first_name
    assert_equal "Person", registration.last_name
    assert_equal "invited-defaults@example.com", registration.email_address
  end

  test "save maps user validation errors onto the registration" do
    registration = user_registration(email_address: users(:one).email_address)

    assert_no_difference -> { User.count } do
      assert_not registration.save
    end

    assert_includes registration.errors[:email_address], "has already been taken"
  end

  test "save rolls back identity records when user creation fails" do
    registration = user_registration(
      email_address: "bad-password@example.com",
      password_confirmation: "different"
    )

    assert_no_difference -> { User.count } do
      assert_no_difference -> { Person.count } do
        assert_no_difference -> { PersonCard.count } do
          assert_no_difference -> { Recording.count } do
            assert_not registration.save
          end
        end
      end
    end

    assert_includes registration.errors[:password_confirmation], "doesn't match Password"
  end

  private

  def user_registration(attributes = {})
    UserRegistration.new(
      {
        first_name: "New",
        last_name: "User",
        email_address: "new-user@example.com",
        password: "password",
        password_confirmation: "password",
        identity_bucket: buckets(:identity)
      }.merge(attributes)
    )
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
