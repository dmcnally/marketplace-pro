require "digest"

class MembershipInvite < ApplicationRecord
  DEFAULT_EXPIRES_IN = 14.days

  attr_reader :token

  belongs_to :bucket
  belongs_to :invited_by, class_name: "Person"
  belongs_to :accepted_by, class_name: "Person", optional: true

  enum :role, Membership.roles

  normalizes :email_address, with: ->(email_address) { email_address.strip.downcase }

  before_validation :set_token_digest, on: :create
  before_validation :set_expires_at, on: :create

  validates :email_address, presence: true
  validates :email_address,
            uniqueness: {
              scope: :bucket_id,
              conditions: -> { where(accepted_at: nil, revoked_at: nil) },
              message: "already has an active invitation for this bucket"
            }
  validates :role, presence: true
  validates :token_digest, presence: true
  validates :expires_at, presence: true
  validate :email_address_is_not_already_member, on: :create
  validates :first_name, presence: true
  validates :last_name, presence: true

  def self.find_by_token(token)
    find_by(token_digest: token_digest_for(token))
  end

  def self.token_digest_for(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def active?
    accepted_at.nil? && revoked_at.nil? && expires_at.future?
  end

  def accepted?
    accepted_at.present?
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at.past?
  end

  def accept_for(person)
    MembershipInviteAcceptance.call(invitation: self, person:)
  end

  def cancel!
    update!(revoked_at: Time.current)
  end

  private

  def set_token_digest
    return if token_digest.present?

    @token = SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.token_digest_for(token)
  end

  def set_expires_at
    self.expires_at ||= DEFAULT_EXPIRES_IN.from_now
  end

  def email_address_is_not_already_member
    return if email_address.blank? || bucket.blank?

    user = User.includes(person: :memberships).find_by(email_address:)
    return unless user&.person&.member_of?(bucket)

    errors.add(:email_address, "already belongs to a member of this bucket")
  end
end
