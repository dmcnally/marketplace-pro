class SessionActions < ActionsBase
  def sign_in_link
    view.link_to "Sign in", view.new_session_path, class: "site-header__link"
  end

  def sign_out_button
    view.button_to "Sign out",
                   view.session_path,
                   method: :delete,
                   class: "site-header__link site-header__link--logout"
  end

  def create_account_link
    view.link_to "Create account", view.new_registration_path, class: "login__link"
  end

  def sign_in_instead_link
    view.link_to "Sign in instead", view.new_session_path, class: "login__link"
  end
end
