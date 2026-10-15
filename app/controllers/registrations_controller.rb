class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  skip_before_action :require_current_bucket, only: %i[ new create ]

  def new
    @registration = build_registration
    @registration.apply_invitation_defaults
  end

  def create
    @registration = build_registration(registration_params)

    if @registration.save
      start_new_session_for @registration.user
      set_current_person

      target_url = after_authentication_url
      return redirect_to no_bucket_path unless Current.bucket || invitation_url?(target_url)

      redirect_to target_url
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def build_registration(attributes = {})
    UserRegistration.new({
      identity_bucket: Bucket.identity,
      invitation_token: session[:invitation_token]
    }.merge(attributes))
  end

  def registration_params
    params.require(:user_registration).permit(
      :email_address,
      :first_name,
      :last_name,
      :password,
      :password_confirmation
    )
  end

  def invitation_url?(url)
    uri = URI.parse(url)
    uri.path.start_with?("/invitations/")
  rescue URI::InvalidURIError
    false
  end
end
