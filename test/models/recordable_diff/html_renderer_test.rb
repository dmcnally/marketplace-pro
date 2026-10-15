require "test_helper"

class RecordableDiff::HtmlRendererTest < ActiveSupport::TestCase
  test "highlights a single inserted word without duplicating the paragraph" do
    html = render_diff(
      previous: "Crossover events have consequences.",
      current: "Crossover events have consequences. XXXX"
    )

    assert_equal 1, html.scan("Crossover events").count
    assert_includes html, "<ins class=\"diffins\"> XXXX</ins>"
  end

  test "highlights deleted and inserted words on one line" do
    html = render_diff(
      previous: "The ship turned left after the signal.",
      current: "The ship turned right after the signal."
    )

    assert_equal 1, html.scan("The ship turned").count
    assert_includes html, "<del class=\"diffmod\">left</del>"
    assert_includes html, "<ins class=\"diffmod\">right</ins>"
  end

  test "highlights a single deleted word inside a paragraph" do
    html = render_diff(
      previous: "The ship turned left after the signal.",
      current: "The ship turned after the signal."
    )

    assert_equal 1, html.scan("The ship turned").count
    assert_includes html, "<del class=\"diffdel\">left </del>"
  end

  test "groups adjacent replacement words" do
    html = render_diff(
      previous: "Mirror Spock implemented after the meeting.",
      current: "Mirror fwefw wefewf after the meeting."
    )

    assert_includes html, "<del class=\"diffmod\">Spock implemented</del>"
    assert_includes html, "<ins class=\"diffmod\">fwefw wefewf</ins>"
  end

  test "does not mark retained suffix words as inserted" do
    html = render_diff(
      previous: "through ruthlessness rather than resistance.",
      current: "through ruthlessness."
    )

    assert_includes html, "through ruthlessness"
    assert_includes html, "<del class=\"diffmod\"> rather than resistance</del>"
    assert_not_includes html, "<ins"
  end

  test "keeps deleted paragraphs grouped before changed following paragraphs" do
    first_paragraph = "The Q Continuum exists outside normal spacetime."
    deleted_paragraph = "The entity known simply as Q took particular interest in humanity."
    changed_previous = "The Continuum itself is not without internal conflict."
    changed_current = "#{changed_previous} I like this very much."

    html = render_diff(
      previous: [ first_paragraph, deleted_paragraph, changed_previous ].join("\n\n"),
      current: [ first_paragraph, changed_current ].join("\n\n")
    )

    assert_includes html, "<del class=\"diffdel\">#{deleted_paragraph}</del>"
    assert_includes html, "The Continuum itself is not without internal conflict."
    assert_includes html, "<ins class=\"diffins\"> I like this very much.</ins>"
    assert_equal 1, html.scan("The Continuum itself").count
  end

  test "escapes source values before rendering html diff" do
    html = render_diff(
      previous: "<script>alert('old')</script>",
      current: "<script>alert('new')</script>"
    )

    assert_includes html, "&lt;script&gt;"
    assert_not_includes html, "<script>"
  end

  private

  def render_diff(previous:, current:)
    RecordableDiff::HtmlRenderer.new(
      previous:,
      current:,
      view_context: ActionController::Base.helpers
    ).render
  end
end
