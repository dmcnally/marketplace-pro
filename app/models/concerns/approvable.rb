module Approvable
  extend ActiveSupport::Concern

  included do
    has_one :approval, as: :approvable, dependent: :destroy

    define_callbacks :approval
  end

  class_methods do
    def before_approval(*args, &block)
      set_callback(:approval, :before, *args, &block)
    end

    def after_approval(*args, &block)
      set_callback(:approval, :after, *args, &block)
    end
  end

  def approve!(updates: NullUpdates::INSTANCE)
    approval_lock.with_lock do
      existing_approval = reload_approval
      return existing_approval if existing_approval.present?

      updates_name = ApprovalUpdates.dump(updates, self)
      created_approval = create_approval!(
        status: "pending",
        person: Current.person
      )

      Approvals::ProcessJob.perform_later(created_approval, updates_name)
      created_approval
    end
  end

  def process_approval!(approval)
    run_callbacks(:approval) do
      on_approval(approval)
    end
  end

  def approvable?
    true
  end

  def approval_lock
    self
  end

  def approved?
    approval&.status == "approved"
  end

  def approval_in_progress?
    return false unless approval.present?

    approval.status.in?(%w[pending approving])
  end

  def on_approval(_approval)
  end
end
