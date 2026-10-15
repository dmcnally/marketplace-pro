class SysAdmin::UserActions
  def initialize(view:, person:)
    @view = view
    @person = person
  end

  def index_link
    return unless sys_admin?

    view.link_to "Users", view.sys_admin_users_path, class: "btn btn--primary"
  end

  def show_link_for(user)
    return unless sys_admin?

    view.link_to "View", view.sys_admin_user_path(user), class: "btn btn--secondary"
  end

  def password_reset_button_for(user)
    return unless sys_admin?

    view.button_to "Reset Password",
                   view.sys_admin_user_password_path(user),
                   method: :post,
                   class: "btn btn--danger",
                   form_class: "user-detail__action-form",
                   form: { data: { turbo_confirm: "Send password reset instructions to #{user.email_address}?" } }
  end

  private

  attr_reader :view, :person

  def sys_admin?
    person.sys_admin?
  end
end
