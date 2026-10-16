class MenuSectionRecordingPolicy < DefaultRecordingPolicy
  def viewable? = person.editor_of?(recording.bucket)
  def editable? = viewable? && recording.kept? && recording.parent&.kept?
  def deletable? = false
end
