class MembershipInviteAcceptance
  class Result
    attr_reader :message, :membership

    def initialize(success:, message:, membership: nil)
      @success = success
      @message = message
      @membership = membership
    end

    def success?
      @success
    end
  end

  def self.call(invitation:, person:)
    new(invitation:, person:).call
  end

  def initialize(invitation:, person:)
    @invitation = invitation
    @person = person
  end

  def call
    return failure("Invitation not found.") unless invitation
    return failure("Sign in to accept this invitation.") unless person&.id
    return failure("Invitation has already been accepted.") if invitation.accepted?
    return failure("Invitation has been revoked.") if invitation.revoked?
    return failure("Invitation has expired.") if invitation.expired?
    return failure("You already have access to this bucket.") if person.member_of?(invitation.bucket)

    membership = nil

    Membership.transaction do
      membership = Membership.create!(
        person:,
        bucket: invitation.bucket,
        role: invitation.role
      )

      invitation.update!(
        accepted_at: Time.current,
        accepted_by: person
      )
    end

    success("Invitation accepted.", membership:)
  end

  private

  attr_reader :invitation, :person

  def success(message, membership:)
    Result.new(success: true, message:, membership:)
  end

  def failure(message)
    Result.new(success: false, message:)
  end
end
