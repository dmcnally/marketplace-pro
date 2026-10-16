class AllergenRecordingPolicy < DefaultRecordingPolicy
  def viewable?
    AllergenPolicy.new(person: person, bucket: recording.bucket).can_view?(recording)
  end

  def editable?
    AllergenPolicy.new(person: person, bucket: recording.bucket).can_edit?(recording)
  end

  def deletable?
    false
  end
end
