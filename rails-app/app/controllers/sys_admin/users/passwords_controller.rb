class SysAdmin::Users::PasswordsController < SysAdminController
  def create
    user = User.find(params[:user_id])
    PasswordsMailer.reset(user).deliver_later

    redirect_to sys_admin_user_path(user), notice: "Password reset instructions sent."
  end
end
