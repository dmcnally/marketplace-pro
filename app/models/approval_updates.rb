class ApprovalUpdates
  DEFAULT_ADAPTERS = { "CsvImport" => "CsvImport::ApprovalCallback" }.freeze

  attr_reader :approvable

  def initialize(approvable)
    @approvable = approvable
  end

  def approving(approval:)
  end

  def approved(approval:)
  end

  def failed(approval:, error:)
  end

  def self.adapters
    DEFAULT_ADAPTERS.merge(Rails.application.config.x.approval_updates.to_h)
  end

  def self.for(approvable, logger: Rails.logger)
    adapter_name = adapters[approvable.class.name]
    unless adapter_name
      logger.info("Using null approval updates adapter for #{approvable.class.name}")
      return NullUpdates::INSTANCE
    end

    load(adapter_name, approvable)
  end

  def self.load(adapter_name, approvable)
    return NullUpdates::INSTANCE if adapter_name == NullUpdates.name
    raise KeyError, "Unregistered approval adapter" unless adapters.fetch(approvable.class.name) == adapter_name

    adapter_class = adapter_name.constantize
    raise TypeError, "Approval adapter must inherit from ApprovalUpdates" unless adapter_class <= ApprovalUpdates

    adapter_class.new(approvable)
  end

  def self.dump(adapter, approvable)
    raise TypeError, "Approval adapter must inherit from ApprovalUpdates" unless adapter.is_a?(ApprovalUpdates)
    return NullUpdates.name if adapter.equal?(NullUpdates::INSTANCE)
    raise KeyError, "Unregistered approval adapter" unless adapters.fetch(approvable.class.name) == adapter.class.name

    adapter.class.name
  end
end
