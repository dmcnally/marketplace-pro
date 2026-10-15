class CsvImportTestRow
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  validates :name, presence: true

  def self.table_attributes
    %w[name]
  end

  def self.from_row(row)
    new(row.slice(*table_attributes))
  end

  def self.import(csv_import)
    csv_import.csv_import_rows.order(:row_number).each do |row|
      csv_import.bucket.recordings.create!(recordable: Article.new(title: row.raw_data.fetch("name")))
    end
  end
end

module CsvImportTestHelper
  extend ActiveSupport::Concern

  included do
    setup do
      @original_import_types = Rails.application.config.x.csv_import_types
      Rails.application.config.x.csv_import_types = { "test_rows" => "CsvImportTestRow" }
    end

    teardown do
      Rails.application.config.x.csv_import_types = @original_import_types
    end
  end

  def create_csv_import(bucket: Current.bucket, created_by: Current.person, filename: "rows.csv", processed: false)
    csv_import = CsvImport.new(bucket:, created_by:, import_type: "test_rows")
    csv_import.source_file.attach(
      io: Rails.root.join("test/examples/#{filename}").open,
      filename:, content_type: "text/csv"
    )
    csv_import.save!
    Import::ProcessFileJob.perform_now(csv_import) if processed
    csv_import
  end
end

class FailingCsvImportTestRow < CsvImportTestRow
  def self.import(csv_import)
    csv_import.csv_import_rows.first.update!(validation_errors: { name: [ "Invalid" ] })
  end
end
