class MenuPolicy < RecordablePolicy
  def can_create? = person.editor_of?(bucket)

  def can_view?(recording)
    assert_recordable!(recording)
    recording.bucket == bucket && can_create?
  end

  def can_edit?(recording) = can_view?(recording) && recording.kept?
end
