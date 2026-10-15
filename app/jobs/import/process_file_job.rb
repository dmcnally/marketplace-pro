class Import::ProcessFileJob < ApplicationJob
  queue_as :default

  def perform(csv_import)
    csv_import.with_lock do
      return if csv_import.status == "complete"

      csv_import.update!(
        status: :processing,
        failure_class: nil,
        failure_message: nil
      )

      klass = csv_import.import_type_class
      csv_import.validate_source!

      csv_import.rows.each do |row|
        csv_import_row = csv_import.csv_import_rows.build(row)

        validator = klass.from_row(row[:raw_data])
        validator.bucket = csv_import.bucket if validator.respond_to?(:bucket=)
        validator.valid?

        csv_import_row.validation_errors = validator.errors.to_hash
        csv_import_row.save!
      end

      csv_import.update!(status: :complete)
    end
    CsvImport::HeaderBroadcast.call(csv_import)
  rescue StandardError => exception
    csv_import.reload
    csv_import.update!(
      status: "failed",
      failure_class: exception.class.name,
      failure_message: exception.message
    )
    CsvImport::HeaderBroadcast.call(csv_import)
  end
end
