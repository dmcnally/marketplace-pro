class CsvImport::HeaderBroadcast
  def self.call(csv_import)
    csv_import.reload

    Turbo::StreamsChannel.broadcast_replace_to(
      csv_import,
      target: ActionView::RecordIdentifier.dom_id(csv_import, :header),
      partial: "admin/csv_imports/header",
      locals: { import: csv_import }
    )
  end
end
