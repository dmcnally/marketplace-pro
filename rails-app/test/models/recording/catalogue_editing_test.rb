require "test_helper"

class Recording::CatalogueEditingTest < ActiveSupport::TestCase
  setup do
    @recording = Current.bucket.recordings.create!(recordable: Category.new(name: "Starters"))
  end

  test "invalid revisions and invalid content leave content and events untouched" do
    revision = @recording.draft_revision
    old_content = @recording.recordable
    assert_no_difference [ "Category.count", "Event.count" ] do
      assert_raises(Recording::CatalogueEditing::StaleDraft) { @recording.revise_content!({ name: "Wrong" }, revision: nil) }
      assert_raises(ActiveRecord::RecordInvalid) { @recording.revise_content!({ name: "" }, revision: revision) }
    end
    assert_equal old_content, @recording.reload.recordable
  end

  test "two editors cannot overwrite or archive using the same old revision" do
    old_revision = @recording.draft_revision
    other = Current.bucket.recordings.find(@recording.id)
    other.revise_content!({ name: "Newest" }, revision: old_revision)
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @recording.revise_content!({ name: "Lost update" }, revision: old_revision) }
    assert_raises(Recording::CatalogueEditing::StaleDraft) { @recording.archive_content!(revision: old_revision) }
    assert_equal "Newest", @recording.reload.recordable.name
    assert @recording.kept?
  end

  test "archive and restore retain content with attributed history and prevent archived editing" do
    original = @recording.recordable
    @recording.archive_content!(revision: @recording.draft_revision)
    assert @recording.reload.discarded?
    assert_raises(Authorization::Denied) { @recording.revise_content!({ name: "No" }, revision: @recording.draft_revision) }
    @recording.restore_content!(revision: @recording.draft_revision)
    assert @recording.reload.kept?
    assert_equal original, @recording.recordable
    assert_equal %w[created discarded restored], @recording.events.order(:id).pluck(:action)
    assert_equal [ Current.person.id ], @recording.events.distinct.pluck(:person_id)
    assert_no_difference "Event.count" do
      @recording.restore_content!(revision: @recording.draft_revision)
    end
  end
end
