class Approvals::ProcessJob < ApplicationJob
  queue_as :default

  def perform(approval, updates_name = NullUpdates.name)
    approvable = approval.approvable
    updates = approval_updates(updates_name, approvable)
    approval.updates = updates

    approvable.approval_lock.with_lock do
      approval.reload
      return if approval.status == "approved"

      approval.update!(status: "approving")
      updates.approving(approval:)

      approvable.process_approval!(approval)

      approval.update!(status: "approved")
    end
  rescue StandardError => error
    approval.update!(status: "failed")
    updates&.failed(approval:, error:)
    raise
  else
    updates.approved(approval:)
  end

  private

  def approval_updates(updates_name, approvable)
    ApprovalUpdates.load(updates_name, approvable)
  end
end
