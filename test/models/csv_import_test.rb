require "test_helper"

class CsvImportTest < ActiveJob::TestCase
  include CsvImportTestHelper

  setup do
    @import = create_csv_import
  end

  test "requires an uploaded CSV file" do
    @import.source_file.detach

    assert_predicate @import, :invalid?
    assert_includes @import.errors[:source_file], "can't be blank"
  end

  test "requires an import type" do
    @import.import_type = nil

    assert_predicate @import, :invalid?
    assert_includes @import.errors[:import_type], "can't be blank"
  end

  test "rejects an unknown import type" do
    @import.import_type = "unknown"

    assert_predicate @import, :invalid?
    assert_includes(
      @import.errors[:import_type],
      "is not included in the list"
    )
  end

  test "requires a bucket" do
    @import.bucket = nil

    assert_predicate @import, :invalid?
    assert_includes @import.errors[:bucket], "must exist"
  end

  test "requires the person who uploaded the file" do
    @import.created_by = nil

    assert_predicate @import, :invalid?
    assert_includes @import.errors[:created_by], "must exist"
  end

  test "reports the CSV columns and number of rows" do
    assert_equal [ "name" ], @import.headers
    assert_equal 1, @import.column_count
    assert_equal 3, @import.row_count
  end

  test "returns numbered rows in their original order" do
    rows = @import.rows

    assert_equal [ 1, 2, 3 ], rows.map { |row| row.fetch(:row_number) }
    assert_equal(
      [
        { "name" => "First row" },
        { "name" => "Second row" },
        { "name" => "Third row" }
      ],
      rows.map { |row| row.fetch(:raw_data) }
    )
  end

  test "describes a failure using its class and message" do
    @import.assign_attributes(
      failure_class: "ArgumentError",
      failure_message: "Missing columns"
    )

    assert_equal(
      "ArgumentError: Missing columns",
      @import.failure_reason
    )
  end

  test "describes a failure when only its message is available" do
    @import.failure_message = "Import failed"

    assert_equal "Import failed", @import.failure_reason
  end

  test "has no failure description before a failure" do
    assert_empty @import.failure_reason
  end

  test "cannot be approved before processing finishes" do
    assert_not_predicate @import, :approvable?
  end

  test "cannot be approved when processing finishes without rows" do
    @import.update!(status: "complete")

    assert_not_predicate @import, :approvable?
  end

  test "can be approved after every row passes validation" do
    import = create_csv_import(processed: true)

    assert_predicate import, :approvable?
  end

  test "cannot be approved while a row is unvalidated" do
    import = create_csv_import(processed: true)
    import.csv_import_rows.first.update!(validation_errors: nil)

    assert_not_predicate import, :approvable?
  end

  test "cannot be approved when a row fails validation" do
    import = create_csv_import(processed: true)
    import.csv_import_rows.first.update!(
      validation_errors: {
        name: [ "Invalid" ]
      }
    )

    assert_not_predicate import, :approvable?
  end

  test "cannot be approved when processing failed" do
    import = create_csv_import(processed: true)
    import.update!(status: "failed")

    assert_not_predicate import, :approvable?
  end

  test "rejects approval before the import is ready" do
    assert_no_enqueued_jobs only: Approvals::ProcessJob do
      assert_no_difference -> { Approval.count } do
        assert_raises(ActiveRecord::RecordInvalid) do
          @import.approve!
        end
      end
    end
  end

  test "creates and queues one approval when requested more than once" do
    import = create_csv_import(processed: true)

    assert_enqueued_jobs 1, only: Approvals::ProcessJob do
      assert_difference -> { Approval.count }, 1 do
        first_approval = import.approve!
        second_approval = CsvImport.find(import.id).approve!

        assert_equal first_approval, second_approval
      end
    end
  end

  test "is approved only after its approval succeeds" do
    import = create_csv_import(processed: true)
    approval = import.approve!

    assert_not_predicate import.reload, :approved?

    approval.update!(status: "approved")

    assert_predicate import.reload, :approved?
  end

  test "removes its rows when deleted" do
    import = create_csv_import(processed: true)
    import_id = import.id

    import.destroy!

    assert_empty CsvImportRow.where(csv_import_id: import_id)
  end
end
