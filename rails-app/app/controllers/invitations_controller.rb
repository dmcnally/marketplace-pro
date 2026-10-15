class InvitationsController < ApplicationController
  allow_unauthenticated_access only: :show
  skip_before_action :require_current_bucket, only: :show

  def show
    @invitation = MembershipInvite.includes(:bucket).find_by_token(params[:token])
    render status: :not_found unless @invitation
  end
end
