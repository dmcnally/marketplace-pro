class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Authorization::Denied, with: :authorization_denied

  before_action :set_current_person
  before_action :require_current_bucket

  helper_method :recordings

  private

  def person_allowed_to?(action, subject)
    PersonAllowedTo.new(person: Current.person, bucket: Current.bucket).allowed?(action, subject)
  end

  def person_allowed_to!(action, subject)
    raise Authorization::Denied unless person_allowed_to?(action, subject)
  end

  def authorization_denied
    head :forbidden
  end

  def recordings
    Current.bucket.recordings
  end

  def set_current_person
    resume_session

    Current.person = Current.user&.person || GuestPerson.new
    Current.bucket = current_content_bucket
    store_current_bucket_preference
  end

  def current_content_bucket
    return Bucket.content.first || Bucket.first if Current.person.guest?

    Current.person.preferred_content_bucket(session[:bucket_id])
  end

  def store_current_bucket_preference
    return unless Current.user

    if Current.bucket.present?
      session[:bucket_id] = Current.bucket.id
    else
      session.delete(:bucket_id)
    end
  end

  def require_current_bucket
    return if Current.user.blank? || Current.bucket.present?

    return redirect_to sys_admin_buckets_path if Current.person.sys_admin?

    redirect_to no_bucket_path
  end
end
