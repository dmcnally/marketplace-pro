class PersonCardRecordingPolicy < DefaultRecordingPolicy
  def editable?
    owner? || person.admin_of?(recording.bucket)
  end

  def deletable?
    person.admin_of?(recording.bucket)
  end

  def viewable?
    owner? || super
  end

  private

  def owner?
    person.person_card == recording.recordable
  end
end
