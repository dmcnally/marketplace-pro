require "csv"
require "digest"

class CsvImport < ApplicationRecord
  include Approvable

  belongs_to :bucket
  belongs_to :created_by, class_name: "Person"

  after_update_commit :broadcast_update

  has_one_attached :source_file
  has_many :csv_import_rows, dependent: :destroy

  validates :source_file,
            presence: true

  validates :import_type,
            presence: true,
            inclusion: { in: ->(_) { Imports::Csv::Types.keys } }

  def failure_reason
    [ failure_class, failure_message ].compact_blank.join(": ")
  end

  def headers
    import_type_class.table_attributes
  end

  def row_count
    csv_table.size
  end

  def rows
    csv_table.each_with_index.map do |row, index|
      {
        row_number: index + 1,
        raw_data: row.to_h,
        row_hash: Digest::SHA256.hexdigest(row.to_h.to_json)
      }
    end
  end

  def column_count
    csv_table.headers.compact.size
  end

  def import_type_class
    Imports::Csv::Types.fetch(import_type)
  end

  def validate_source!
    missing_headers = headers - csv_table.headers.compact
    raise ArgumentError, "Missing required CSV columns: #{missing_headers.join(', ')}" if missing_headers.any?
    raise ArgumentError, "The CSV contains no data rows" if csv_table.empty?
  end

  def approvable?
    status == "complete" && csv_import_rows.exists? &&
      !csv_import_rows.where("validation_errors IS NULL OR validation_errors <> ?", {}.to_json).exists?
  end

  def approve!(updates: NullUpdates::INSTANCE)
    with_lock do
      reload_approval
      return approval if approval.present?

      ensure_approvable!
      super
    end
  end

  def on_approval(_approval)
    unless import_type_class.respond_to?(:import)
      raise NotImplementedError, "#{import_type_class.name} must implement .import(csv_import)"
    end

    transaction(requires_new: true) do
      validate_source!
      ensure_approvable!
      import_type_class.import(self)
      ensure_approvable!
    end
  end

  private

  def ensure_approvable!
    return if approvable?

    errors.add(:base, "Import must finish processing and contain at least one row, with no validation errors, before approval")
    csv_import_rows.where.not(validation_errors: {}).each do |row|
      (row.validation_errors || {}).each do |attribute, messages|
        Array(messages).each do |message|
          label = attribute == "base" ? "" : "#{attribute.humanize} "
          errors.add(:base, "Row #{row.row_number}: #{label}#{message}")
        end
      end
    end
    raise ActiveRecord::RecordInvalid, self
  end

  def csv_table
    @csv_table ||= CSV.parse(source_file.download, headers: true)
  end

  def broadcast_update
    %w[all errors valid].each do |filter|
      Turbo::StreamsChannel.broadcast_update_to(
        self, filter,
        target: self,
        partial: "admin/csv_imports/csv_import",
        locals: { import: self, selected_filter: filter }
      )
    end
  end
end
