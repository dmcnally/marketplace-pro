class TimelineActions < ActionsBase
  def render_for(recording)
    view.render "timelines/timeline", recording:
  end
end
