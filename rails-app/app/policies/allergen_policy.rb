class AllergenPolicy < RecordablePolicy
  def can_create?
    person.editor_of?(bucket)
  end

  def can_view?(recording)
    assert_recordable!(recording)
    recording.bucket == bucket && can_create?
  end

  def can_edit?(recording)
    can_view?(recording) && recording.kept?
  end

  def can_archive?(recording)
    can_edit?(recording)
  end

  def can_restore?(recording)
    can_view?(recording) && recording.discarded?
  end
end
