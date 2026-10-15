class UserRegistration
  include ActiveModel::Model

  attr_accessor :first_name,
                :last_name,
                :email_address,
                :password,
                :password_confirmation,
                :identity_bucket

  attr_reader :invitation_token, :user

  validates :first_name,
            :last_name,
            :email_address,
            :password,
            :password_confirmation, presence: true
  validate :identity_bucket_must_be_available

  def invitation_token=(token)
    @invitation_token = token.presence
    remove_instance_variable(:@invitation) if defined?(@invitation)
  end

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      person_card = PersonCard.create!(first_name:, last_name:)
      recording = identity_bucket.recordings.create!(recordable: person_card)
      person = Person.create!(recording:)

      @user = User.new(email_address:, password:, password_confirmation:, person:)
      @user.save!
    end

    true
  rescue ActiveRecord::RecordInvalid => error
    merge_errors_from(error.record)
    false
  rescue ActiveRecord::RecordNotUnique
    errors.add(:email_address, "has already been taken")
    false
  end

  def apply_invitation_defaults
    return unless active_invitation

    self.email_address = active_invitation.email_address if email_address.blank?
    self.first_name = active_invitation.first_name if first_name.blank?
    self.last_name = active_invitation.last_name if last_name.blank?
  end

  private

  def active_invitation
    invitation if invitation&.active?
  end

  def invitation
    return if invitation_token.blank?
    return @invitation if defined?(@invitation)

    @invitation = MembershipInvite.find_by_token(invitation_token)
  end

  def identity_bucket_must_be_available
    errors.add(:identity_bucket, "must exist") unless identity_bucket
  end

  def merge_errors_from(record)
    record.errors.each { |error| errors.add(error.attribute, error.message) }
  end
end
