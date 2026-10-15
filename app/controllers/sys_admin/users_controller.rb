class SysAdmin::UsersController < SysAdminController
  before_action :set_user, only: [ :show ]

  def index
    @users = User.includes(person: { recording: :recordable }).order(:email_address)
  end

  def show
  end

  private

  def set_user
    @user = User.includes(:sessions, person: [ :memberships, { recording: :recordable } ]).find(params[:id])
    @memberships = @user.person.memberships.includes(:bucket).order("buckets.name")
  end
end
