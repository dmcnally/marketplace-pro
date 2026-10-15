module RecordableDiffsHelper
  def inline_diff_for(previous_value, current_value)
    tag.div(
      RecordableDiff::HtmlRenderer.new(
        previous: previous_value,
        current: current_value,
        view_context: self
      ).render,
      class: "html-diff"
    )
  end
end
