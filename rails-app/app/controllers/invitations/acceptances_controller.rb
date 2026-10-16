class Invitations::AcceptancesController < ApplicationController
  prepend_before_action :store_invitation_return_path, unless: :authenticated?

  skip_before_action :require_current_bucket

  def create
    invitation = MembershipInvite.includes(:bucket).find_by_token(params[:token])
    result = MembershipInviteAcceptance.call(invitation:, person: Current.person)

    if result.success?
      session.delete(:return_to_after_authenticating)
      session[:bucket_id] = result.membership.bucket_id
      redirect_to overview_path, notice: result.message
    else
      redirect_to invitation_path(params[:token]), alert: result.message
    end
  end

  private

  def store_invitation_return_path
    session[:invitation_token] = params[:token]
    session[:return_to_after_authenticating] = invitation_path(params[:token])
  end
end
