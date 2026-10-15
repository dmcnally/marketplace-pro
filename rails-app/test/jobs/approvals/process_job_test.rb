require "test_helper"

class Approvals::ProcessJobTest < ActiveJob::TestCase
  include CsvImportTestHelper

  setup do
    @person = Current.person
    @bucket = Current.bucket
  end

  test "imports the records and marks the approval as approved" do
    import = create_import
    approval = import.approve!

    assert_difference -> { @bucket.recordings.articles.count }, 3 do
      Approvals::ProcessJob.perform_now(approval)
    end

    assert import.reload.approved?
    assert_equal [
      "First row",
      "Second row",
      "Third row"
    ], @bucket.recordings.articles.order(:id).map { |recording|
      recording.recordable.title
    }
  end

  test "records approval progress in the event history" do
    import = create_import
    approval = import.approve!

    Approvals::ProcessJob.perform_now(approval)

    assert_equal(
      %w[pending approving approved],
      approval.events.order(:id).pluck(:action)
    )
  end

  test "does not import records again when the approval is already complete" do
    import = create_import
    approval = import.approve!
    Approvals::ProcessJob.perform_now(approval)

    assert_no_difference -> { @bucket.recordings.articles.count } do
      Approvals::ProcessJob.perform_now(approval)
    end

    assert import.reload.approved?
  end

  test "marks the approval as failed and raises the processing error" do
    use_failing_import_type
    import = create_import
    approval = import.approve!

    assert_raises(ActiveRecord::RecordInvalid) do
      Approvals::ProcessJob.perform_now(approval)
    end

    assert_equal "failed", approval.reload.status
    refute import.reload.approved?
  end

  test "rolls back import changes when processing fails" do
    use_failing_import_type
    import = create_import
    approval = import.approve!

    assert_raises(ActiveRecord::RecordInvalid) do
      Approvals::ProcessJob.perform_now(approval)
    end

    assert_equal 3, import.reload.csv_import_rows.count
    assert import.csv_import_rows.all?(&:validated_successfully?)
  end

  test "successfully processes a failed approval when retried" do
    use_failing_import_type
    import = create_import
    approval = import.approve!

    assert_raises(ActiveRecord::RecordInvalid) do
      Approvals::ProcessJob.perform_now(approval)
    end
    assert_equal "failed", approval.reload.status

    Rails.application.config.x.csv_import_types["test_rows"] = "CsvImportTestRow"

    assert_difference -> { @bucket.recordings.articles.count }, 3 do
      Approvals::ProcessJob.perform_now(approval)
    end

    assert import.reload.approved?
  end

  private

  def create_import
    create_csv_import(
      bucket: @bucket,
      created_by: @person,
      processed: true
    )
  end

  def use_failing_import_type
    Rails.application.config.x.csv_import_types["test_rows"] =
      "FailingCsvImportTestRow"
  end
end
