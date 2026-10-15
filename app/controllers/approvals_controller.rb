class ApprovalsController < ApplicationController
  # POST /approval
  def create # rubocop:todo Controllers/MultipleInstanceVariables
    @approvable =  GlobalID::Locator.locate_signed(params[:approvable], for: "approval")
    raise ActiveRecord::RecordNotFound unless @approvable
    raise ActiveRecord::RecordNotFound unless @approvable.respond_to?(:approve!)

    person_allowed_to!(:approve, @approvable)
    return head :forbidden if @approvable.approved?

    return head :unprocessable_entity unless @approvable.approvable?

    updates = ApprovalUpdates.for(@approvable)
    @approval = @approvable.approve!(updates:)

    respond_to do |format|
      format.turbo_stream
      format.html { head :ok }
    end
  end
end
