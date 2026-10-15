class CsvImport::ApprovalCallback < ApprovalUpdates
  def approved(approval:)
    CsvImport::HeaderBroadcast.call(approvable)
  end

  def failed(approval:, error:)
    CsvImport::HeaderBroadcast.call(approvable)
  end
end
