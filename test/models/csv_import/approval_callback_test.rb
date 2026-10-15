require "test_helper"

class CsvImport::ApprovalCallbackTest < ActionView::TestCase
  include CsvImportTestHelper
  include Turbo::Broadcastable::TestHelper

  setup do
    @import = create_csv_import(processed: true)
    @approval = Approval.create!(
      approvable: @import,
      person: Current.person
    )
    @updates = CsvImport::ApprovalCallback.new(@import)
  end

  test "shows approved in the header after approval succeeds" do
    @approval.update!(status: "approved")

    streams = capture_turbo_stream_broadcasts(@import) do
      @updates.approved(approval: @approval)
    end

    assert_equal 1, streams.size

    assert_select(
      streams.first,
      "template .csv-import-detail__approval-status",
      text: "Approved"
    )
  end

  test "shows awaiting approval in the header after approval fails" do
    @approval.update!(status: "failed")

    streams = capture_turbo_stream_broadcasts(@import) do
      @updates.failed(
        approval: @approval,
        error: StandardError.new("Import failed")
      )
    end

    assert_equal 1, streams.size

    assert_select(
      streams.first,
      "template .csv-import-detail__approval-status",
      text: "Awaiting approval"
    )
  end

  test "does not update the header when approval starts" do
    @approval.update!(status: "approving")

    assert_turbo_stream_broadcasts(@import, count: 0) do
      @updates.approving(approval: @approval)
    end
  end
end
