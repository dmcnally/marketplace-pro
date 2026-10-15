class NullUpdates < ApprovalUpdates
  def initialize
    super(nil)
  end

  INSTANCE = new.freeze

  private

  def method_missing(...)
    nil
  end

  def respond_to_missing?(*)
    true
  end
end
