require "test_helper"

class Import::ProcessFileJobTest < ActiveJob::TestCase
  include CsvImportTestHelper

  setup do
    @person = Current.person
    @bucket = Current.bucket
  end

  test "extracts CSV rows in their original order" do
    import = create_import

    Import::ProcessFileJob.perform_now(import)

    import_rows = import.reload.csv_import_rows.order(:row_number)

    assert_equal "complete", import.status
    assert_equal [ 1, 2, 3 ], import_rows.map(&:row_number)
    assert_equal [
      "First row",
      "Second row",
      "Third row"
    ], import_rows.map { |import_row| import_row.raw_data["name"] }
    assert import_rows.all?(&:validated_successfully?)
  end

  test "records validation errors and continues processing the remaining rows" do
    import = create_import(filename: "rows_invalid.csv")

    Import::ProcessFileJob.perform_now(import)

    invalid_row, valid_row = import.reload.csv_import_rows.order(:row_number)

    assert_equal "complete", import.status
    assert invalid_row.validation_failed?
    assert_equal [ "can't be blank" ], invalid_row.validation_errors["name"]
    assert valid_row.validated_successfully?
    refute import.approvable?
  end

  test "fails when required columns are missing" do
    import = create_import(filename: "rows_missing_headers.csv")

    Import::ProcessFileJob.perform_now(import)

    assert_equal "failed", import.reload.status
    assert_match "Missing required CSV columns: name", import.failure_reason
    assert_empty import.csv_import_rows
  end

  test "fails when the CSV contains no data rows" do
    import = create_import(filename: "rows_empty.csv")

    Import::ProcessFileJob.perform_now(import)

    assert_equal "failed", import.reload.status
    assert_match "The CSV contains no data rows", import.failure_reason
    assert_empty import.csv_import_rows
  end

  test "fails when the CSV is malformed" do
    import = create_import(filename: "rows_broken.csv")

    Import::ProcessFileJob.perform_now(import)

    assert_equal "failed", import.reload.status
    assert_match "CSV::MalformedCSVError", import.failure_reason
    assert_empty import.csv_import_rows
  end

  test "does not create articles or approve the import while processing the file" do
    import = create_import

    assert_no_difference -> { @bucket.recordings.articles.count } do
      Import::ProcessFileJob.perform_now(import)
    end

    assert_equal "complete", import.reload.status
    refute import.approved?
  end

  test "does not change another import" do
    import = create_import
    other_import = create_import(filename: "rows_invalid.csv")

    Import::ProcessFileJob.perform_now(import)

    assert_equal "complete", import.reload.status
    assert_equal "pending", other_import.reload.status
    assert_empty other_import.csv_import_rows
  end

  test "clears the previous failure after a successful retry" do
    import = create_import(filename: "rows_missing_headers.csv")

    Import::ProcessFileJob.perform_now(import)

    assert_equal "failed", import.reload.status
    assert_match "Missing required CSV columns", import.failure_reason

    Rails.root.join("test/examples/rows.csv").open do |source_file|
      import.source_file.attach(
        io: source_file,
        filename: "rows.csv",
        content_type: "text/csv"
      )
    end

    Import::ProcessFileJob.perform_later(import)
    perform_enqueued_jobs

    assert_equal "complete", import.reload.status
    assert_empty import.failure_reason
    assert_equal 3, import.csv_import_rows.count
    assert import.approvable?
  end

  test "keeps the import complete without duplicating rows when processing runs again" do
    import = create_import
    Import::ProcessFileJob.perform_now(import)
    assert_equal "complete", import.reload.status

    assert_no_difference -> { import.csv_import_rows.count } do
      Import::ProcessFileJob.perform_now(import)
    end

    assert_equal "complete", import.reload.status
    assert_equal 3, import.csv_import_rows.count
    assert_empty import.failure_reason
  end

  private

  def create_import(filename: "rows.csv")
    create_csv_import(
      bucket: @bucket,
      created_by: @person,
      filename: filename
    )
  end
end
