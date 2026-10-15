require "test_helper"

class RecordableDiffTest < ActiveSupport::TestCase
  setup do
    @recording = Current.bucket.recordings.create!(
      recordable: Article.new(title: "Original title", body: "Original body")
    )
  end

  test "returns no changes when there is no previous updated event" do
    diff = RecordableDiff.previous(@recording)

    assert_nil diff.previous
    assert_equal({}, diff.changes)
  end

  test "finds the latest updated event with a previous subject" do
    first_article = @recording.recordable

    @recording.update!(recordable: Article.new(title: "Second title", body: "Second body"))
    second_article = @recording.recordable

    @recording.update!(recordable: Article.new(title: "Third title", body: "Third body"))

    diff = RecordableDiff.previous(@recording)

    assert_equal second_article, diff.previous
    assert_not_equal first_article, diff.previous
  end

  test "reports changed fields using Active Record Dirty shape" do
    @recording.update!(recordable: Article.new(title: "Updated title", body: "Updated body"))

    diff = RecordableDiff.previous(@recording)

    assert_equal [ "Original title", "Updated title" ], diff.changes["title"]
    assert_equal [ "Original body", "Updated body" ], diff.changes["body"]
  end

  test "omits unchanged fields" do
    @recording.update!(recordable: Article.new(title: "Updated title", body: "Original body"))

    diff = RecordableDiff.previous(@recording)

    assert_equal [ "Original title", "Updated title" ], diff.changes["title"]
    assert_not diff.changes.key?("body")
  end

  test "respects recordable fields" do
    original_method = Article.method(:recordable_fields)
    Article.define_singleton_method(:recordable_fields) { [ "title" ] }

    begin
      @recording.update!(recordable: Article.new(title: "Updated title", body: "Updated body"))

      diff = RecordableDiff.previous(@recording)

      assert_equal({ "title" => [ "Original title", "Updated title" ] }, diff.changes)
    ensure
      Article.define_singleton_method(:recordable_fields) { original_method.call }
    end
  end

  test "changes include unchanged field content outside the edit" do
    original_body = "First paragraph\n\nSecond paragraph\n\nThird paragraph"
    updated_body = "First paragraph\n\nSecond paragraph changed\n\nThird paragraph"
    recording = Current.bucket.recordings.create!(
      recordable: Article.new(title: "Title", body: original_body)
    )
    recording.update!(recordable: Article.new(title: "Title", body: updated_body))

    previous_value, current_value = RecordableDiff.previous(recording).changes["body"]

    assert_includes previous_value, "First paragraph"
    assert_includes current_value, "Third paragraph"
    assert_includes current_value, "changed"
  end

  test "raises when current and previous classes differ" do
    article = Article.create!(title: "Current title")
    comment = Comment.create!(body: "Previous comment")

    error = assert_raises(RecordableDiff::IncompatibleRecordableTypes) do
      RecordableDiff.new(current: article, previous: comment, event: nil)
    end

    assert_equal "Cannot compare Article with Comment", error.message
  end
end
