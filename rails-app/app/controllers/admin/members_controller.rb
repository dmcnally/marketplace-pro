class Admin::MembersController < ApplicationController
  layout "management"

  before_action :require_bucket_admin

  def index
    @memberships = Current.bucket.memberships
                                 .includes(person: :user)
                                 .preload(person: { recording: :recordable })
                                 .order(:role, :id)
  end

  private

  def require_bucket_admin
    head :forbidden unless Current.person&.admin_of?(Current.bucket)
  end
end
