require "test_helper"

class ApprovalUpdatesTest < ActiveSupport::TestCase
  include CsvImportTestHelper

  setup do
    @import = create_csv_import
    @original_updates = Rails.application.config.x.approval_updates
  end

  teardown do
    Rails.application.config.x.approval_updates = @original_updates
  end

  test "provides CSV import updates for a CSV import" do
    updates = ApprovalUpdates.for(@import)

    assert_instance_of CsvImport::ApprovalCallback, updates
    assert_equal @import, updates.approvable
  end

  test "does nothing when the subject has no registered updates" do
    updates = ApprovalUpdates.for(Article.new(title: "Example"))

    assert_nil updates.approving(approval: nil)
    assert_nil updates.approved(approval: nil)
    assert_nil updates.failed(
      approval: nil,
      error: StandardError.new("Failed")
    )
  end

  test "allows approval updates to be disabled for CSV imports" do
    Rails.application.config.x.approval_updates = {
      "CsvImport" => "NullUpdates"
    }

    assert_instance_of NullUpdates, ApprovalUpdates.for(@import)
  end

  test "restores saved updates for the supplied import" do
    saved_updates = ApprovalUpdates.dump(
      ApprovalUpdates.for(@import),
      @import
    )
    other_import = create_csv_import

    restored_updates = ApprovalUpdates.load(saved_updates, other_import)

    assert_instance_of CsvImport::ApprovalCallback, restored_updates
    assert_equal other_import, restored_updates.approvable
  end

  test "restores saved updates that do nothing" do
    article = Article.new(title: "Example")
    saved_updates = ApprovalUpdates.dump(
      ApprovalUpdates.for(article),
      article
    )

    restored_updates = ApprovalUpdates.load(saved_updates, article)

    assert_instance_of NullUpdates, restored_updates
  end

  test "rejects updates that are not registered for the subject" do
    assert_raises(KeyError) do
      ApprovalUpdates.load("ApprovalUpdates", @import)
    end
  end

  test "rejects a registered class that cannot provide approval updates" do
    Rails.application.config.x.approval_updates = {
      "CsvImport" => "String"
    }

    assert_raises(TypeError) do
      ApprovalUpdates.for(@import)
    end
  end

  test "rejects saving updates that are not registered for the subject" do
    assert_raises(KeyError) do
      ApprovalUpdates.dump(ApprovalUpdates.new(@import), @import)
    end
  end
end
