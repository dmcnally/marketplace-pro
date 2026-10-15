require "test_helper"

class CsvImport::HeaderBroadcastTest < ActionView::TestCase
  include CsvImportTestHelper
  include Turbo::Broadcastable::TestHelper

  setup do
    @import = create_csv_import(processed: true)

    Membership.create!(
      person: Current.person,
      bucket: Current.bucket,
      role: :admin
    )
  end

  test "replaces the import header with its current details" do
    streams = capture_turbo_stream_broadcasts(@import) do
      CsvImport::HeaderBroadcast.call(@import)
    end

    assert_equal 1, streams.size

    stream = streams.first

    assert_equal "replace", stream["action"]
    assert_equal dom_id(@import, :header), stream["target"]
    assert_select stream, "template h1", text: "rows.csv"
    assert_select(
      stream,
      "template .csv-import-detail__meta",
      text: /Test User/
    )
    assert_select(
      stream,
      "template .csv-import-detail__type",
      text: "Test Rows"
    )
    assert_select stream, "template button", text: "Approve"
  end

  test "shows an approval saved after the import was loaded" do
    Approval.create!(
      approvable: CsvImport.find(@import.id),
      person: Current.person,
      status: "approved"
    )

    streams = capture_turbo_stream_broadcasts(@import) do
      CsvImport::HeaderBroadcast.call(@import)
    end

    assert_equal 1, streams.size

    assert_select(
      streams.first,
      "template .csv-import-detail__approval-status",
      text: "Approved"
    )
    assert_select streams.first, "template button", count: 0
  end

  test "does not broadcast the header to another import" do
    other_import = create_csv_import

    assert_turbo_stream_broadcasts(other_import, count: 0) do
      CsvImport::HeaderBroadcast.call(@import)
    end
  end
end
