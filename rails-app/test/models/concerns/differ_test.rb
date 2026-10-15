require "test_helper"

class DifferTest < ActiveSupport::TestCase
  setup do
    @recording = Current.bucket.recordings.create!(
      recordable: Article.new(title: "Original title", body: "Original body")
    )
  end

  test "recording is diffable when its recordable is diffable" do
    assert @recording.diffable?
  end

  test "previous_diff returns a recordable diff for the recording" do
    @recording.update!(recordable: Article.new(title: "Updated title", body: "Original body"))

    diff = @recording.previous_diff

    assert_instance_of RecordableDiff, diff
    assert_equal [ "Original title", "Updated title" ], diff.changes["title"]
  end
end
