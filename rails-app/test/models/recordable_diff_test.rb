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

  test "image comparisons preserve additions replacements and removals for catalogue content" do
    [ Product, Menu, MenuSection ].each do |klass|
      original = klass.create!(name: "Original")
      illustrated = klass.new(name: "Original")
      illustrated.image.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "image.png", content_type: "image/png")
      illustrated.save!
      replaced = klass.new(name: "Original")
      replaced.image.attach(io: File.open(Rails.root.join("public/icon.png")), filename: "image.png", content_type: "image/png")
      replaced.save!
      assert_equal [ nil, illustrated.image.blob ], RecordableDiff.new(previous: original, current: illustrated, event: nil).image_change
      assert_equal [ illustrated.image.blob, replaced.image.blob ], RecordableDiff.new(previous: illustrated, current: replaced, event: nil).image_change
      assert_equal [ replaced.image.blob, nil ], RecordableDiff.new(previous: replaced, current: original, event: nil).image_change
      assert_nil RecordableDiff.new(previous: illustrated, current: illustrated, event: nil).image_change
      assert illustrated.reload.image.attached?
    end
    assert_nil RecordableDiff.previous(@recording).image_change
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
