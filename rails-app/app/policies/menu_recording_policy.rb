class MenuRecordingPolicy < DefaultRecordingPolicy
  def viewable? = person.editor_of?(recording.bucket)
  def editable? = viewable? && recording.kept?
  def deletable? = false
end
