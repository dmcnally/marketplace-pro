class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  skip_before_action :require_current_bucket, only: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
    membership_invite = MembershipInvite.find_by_token(session[:invitation_token])
    @email_address = membership_invite&.email_address if membership_invite
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      set_current_person

      target_url = after_authentication_url
      return redirect_to target_url if Current.bucket || invitation_url?(target_url) || sys_admin_url?(target_url)
      return redirect_to sys_admin_root_path if Current.person.sys_admin?

      redirect_to no_bucket_path
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  def invitation_url?(url)
    uri = URI.parse(url)
    uri.path.start_with?("/invitations/")
  rescue URI::InvalidURIError
    false
  end

  def sys_admin_url?(url)
    return false unless Current.person.sys_admin?

    uri = URI.parse(url)
    uri.path.start_with?("/sys_admin")
  rescue URI::InvalidURIError
    false
  end
end
