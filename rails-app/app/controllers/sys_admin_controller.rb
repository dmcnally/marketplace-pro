class SysAdminController < ::ApplicationController
  layout "management"

  skip_before_action :require_current_bucket
  before_action :require_sys_admin

  private

  def require_sys_admin
    head :forbidden unless Current.person&.sys_admin?
  end
end
