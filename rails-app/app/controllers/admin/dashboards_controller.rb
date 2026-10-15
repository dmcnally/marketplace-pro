class Admin::DashboardsController < ApplicationController
  layout "admin_workspace"

  before_action :require_bucket_admin

  def show
    @overview = Admin::WorkspaceOverview.new(bucket: Current.bucket, person: Current.person)
  end

  private

  def require_bucket_admin
    head :forbidden unless Current.person&.admin_of?(Current.bucket)
  end
end
