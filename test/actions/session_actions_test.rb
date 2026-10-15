require "test_helper"

class SessionActionsTest < ActiveSupport::TestCase
  setup do
    @actions = SessionActions.new(view: FakeSessionView.new, person: Current.person, bucket: Current.bucket)
  end

  test "sign in link renders" do
    assert_equal(
      {
        label: "Sign in",
        path: "/session/new",
        options: { class: "site-header__link" }
      },
      @actions.sign_in_link
    )
  end

  test "sign out button renders" do
    assert_equal(
      {
        label: "Sign out",
        path: "/session",
        options: { method: :delete, class: "site-header__link site-header__link--logout" }
      },
      @actions.sign_out_button
    )
  end

  test "create account link renders" do
    assert_equal(
      {
        label: "Create account",
        path: "/registration/new",
        options: { class: "login__link" }
      },
      @actions.create_account_link
    )
  end

  test "sign in instead link renders" do
    assert_equal(
      {
        label: "Sign in instead",
        path: "/session/new",
        options: { class: "login__link" }
      },
      @actions.sign_in_instead_link
    )
  end

  class FakeSessionView
    def link_to(label, path, options = {})
      { label:, path:, options: }
    end

    def button_to(label, path, options = {})
      { label:, path:, options: }
    end

    def new_session_path
      "/session/new"
    end

    def session_path
      "/session"
    end

    def new_registration_path
      "/registration/new"
    end
  end
end
