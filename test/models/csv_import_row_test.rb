require "test_helper"

class CsvImportRowTest < ActiveSupport::TestCase
  include CsvImportTestHelper

  setup do
    @import = create_csv_import(processed: true)
    @row = @import.csv_import_rows.order(:row_number).first
  end

  test "requires an import" do
    @row.csv_import = nil

    assert_predicate @row, :invalid?
    assert_includes @row.errors[:csv_import], "must exist"
  end

  test "requires a row number" do
    @row.row_number = nil

    assert_predicate @row, :invalid?
    assert_includes @row.errors[:row_number], "can't be blank"
  end

  test "requires the source data for the row" do
    @row.raw_data = {}

    assert_predicate @row, :invalid?
    assert_includes @row.errors[:raw_data], "can't be blank"
  end

  test "reports a row without a validation result as unvalidated" do
    @row.update!(validation_errors: nil)

    assert_predicate @row.reload, :unvalidated?
  end

  test "reports a row without validation errors as successful" do
    @row.update!(validation_errors: {})

    assert_predicate @row.reload, :validated_successfully?
  end

  test "reports a row with validation errors as failed" do
    @row.update!(
      validation_errors: {
        name: [ "Invalid" ]
      }
    )

    assert_predicate @row.reload, :validation_failed?
    assert_equal(
      { "name" => [ "Invalid" ] },
      @row.validation_errors
    )
  end

  test "keeps the original source data after validation fails" do
    @row.update!(
      validation_errors: {
        name: [ "Invalid" ]
      }
    )

    assert_equal(
      { "name" => "First row" },
      @row.reload.raw_data
    )
  end

  test "does not allow the same row number twice in one import" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      CsvImportRow.transaction(requires_new: true) do
        CsvImportRow.create!(
          csv_import: @import,
          row_number: @row.row_number,
          raw_data: { "name" => "Duplicate row" },
          row_hash: "duplicate-row"
        )
      end
    end
  end

  test "allows the same row number in different imports" do
    other_import = create_csv_import

    row = CsvImportRow.create!(
      csv_import: other_import,
      row_number: @row.row_number,
      raw_data: { "name" => "Other import row" },
      row_hash: "other-import-row"
    )

    assert_equal @row.row_number, row.row_number
    assert_equal other_import, row.csv_import
  end
end
