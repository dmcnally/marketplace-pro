class Admin::InvitationsController < ApplicationController
  layout "management"

  before_action :require_bucket_admin
  before_action :set_invitation, only: :destroy

  def index # rubocop:todo Controllers/MultipleInstanceVariables
    @invitations = Current.bucket.membership_invites
                                 .includes(:invited_by)
                                 .order(created_at: :desc)
    @sent_invitations = @invitations.select(&:active?)
    @accepted_invitations = @invitations.select { |invitation| invitation.accepted_at&.after?(30.days.ago) }
    @expired_invitations = @invitations.select { |invitation| invitation.expired? && !invitation.accepted? }
  end

  def new
    @invitation = Current.bucket.membership_invites.new
  end

  def create
    @invitation = Current.bucket.membership_invites.new(invitation_params)
    role = invitation_role
    @invitation.role = role if role
    @invitation.invited_by = Current.person

    if @invitation.save
      MembershipInvitesMailer.invite(@invitation, @invitation.token).deliver_later
      redirect_to admin_invitations_path, notice: "Invitation was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if @invitation.active?
      @invitation.cancel!
      redirect_to admin_invitations_path, notice: "Invitation was successfully canceled.", status: :see_other
    else
      redirect_to admin_invitations_path, alert: "Only sent invitations can be canceled.", status: :see_other
    end
  end

  private

  def set_invitation
    @invitation = Current.bucket.membership_invites.find(params[:id])
  end

  def require_bucket_admin
    head :forbidden unless Current.person&.admin_of?(Current.bucket)
  end

  def invitation_params
    params.require(:membership_invite).permit(:email_address, :first_name, :last_name)
  end

  def invitation_role
    role = params.require(:membership_invite)[:role].to_s
    return role if Membership.roles.key?(role)

    nil
  end
end
