require "test_helper"

class EventTest < ActionView::TestCase
  include CsvImportTestHelper

  setup do
    @import = create_csv_import
    @approval = Approval.create!(
      approvable: @import,
      person: Current.person
    )
    events = @approval.events.to_a
    assert_equal 1, events.size
    @event = events.first
  end

  test "describes a CSV import in an approval event" do
    assert_equal "csv import", @event.timeline_description
  end

  test "uses the default timeline entry for a CSV approval event" do
    assert_equal "timelines/event", @event.partial_path
  end

  test "displays a CSV approval event in the timeline" do
    render partial: @event.partial_path, locals: { event: @event }

    assert_select ".timeline__action", text: "Pending"
    assert_select ".timeline__subject", text: "csv import"
    assert_select ".timeline__actor", text: "by Test User"
  end

  test "uses the comment timeline entry for a comment event" do
    article = Current.bucket.recordings.create!(
      recordable: Article.new(title: "Example")
    )
    comment = article.children.create!(
      recordable: Comment.new(body: "A comment")
    )
    event = comment.events.first

    assert_equal(
      "timelines/events/created_comment",
      event.partial_path
    )
  end

  test "displays a comment event in the timeline" do
    article = Current.bucket.recordings.create!(
      recordable: Article.new(title: "Example")
    )
    comment = article.children.create!(
      recordable: Comment.new(body: "A comment")
    )
    event = comment.events.first

    render partial: event.partial_path, locals: { event: event }

    assert_select ".timeline__comment", text: "A comment"
  end
end
