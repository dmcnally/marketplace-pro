class Person < ApplicationRecord
  belongs_to :recording

  has_one :user, dependent: :restrict_with_exception
  has_many :memberships, dependent: :destroy
  has_many :buckets, through: :memberships

  delegate :recordable, to: :recording
  alias_method :person_card, :recordable

  def guest?
    false
  end

  def membership_for(bucket)
    memberships.find_by(bucket: bucket)
  end

  # First check: do person and resource share a bucket?
  def member_of?(bucket)
    membership_for(bucket).present?
  end

  def preferred_content_bucket(preferred_bucket_id)
    return preferred_sys_admin_content_bucket(preferred_bucket_id) if sys_admin?

    member_content_buckets.find_by(id: preferred_bucket_id) || member_content_buckets.order(:id).first
  end

  def switchable_content_bucket?(bucket)
    bucket.present? && bucket.content? && (sys_admin? || member_of?(bucket))
  end

  # Role checks (implicitly require membership)
  def admin_of?(bucket)
    membership_for(bucket)&.admin? || sys_admin?
  end

  def editor_of?(bucket)
    role = membership_for(bucket)
    role&.admin? || role&.editor? || sys_admin?
  end

  def viewer_of?(bucket)
    member_of?(bucket) || sys_admin?
  end

  def sys_admin?
    @sys_admin ||= Bucket.system_bucket&.then { |bucket| membership_for(bucket)&.admin? } || false
  end

  private

  def member_content_buckets
    buckets.content
  end

  def preferred_sys_admin_content_bucket(preferred_bucket_id)
    Bucket.content.find_by(id: preferred_bucket_id)
  end
end
