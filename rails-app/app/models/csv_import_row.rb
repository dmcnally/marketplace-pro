class CsvImportRow < ApplicationRecord
  belongs_to :csv_import

  validates :row_number, presence: true
  validates :raw_data, presence: true

  def validated_successfully?
    validation_errors == {}
  end

  def validation_failed?
    validation_errors.present? && validation_errors != {}
  end

  def unvalidated?
    validation_errors.nil?
  end
end
