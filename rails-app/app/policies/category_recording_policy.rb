class CategoryRecordingPolicy < DefaultRecordingPolicy
  def viewable?
    CategoryPolicy.new(person: person, bucket: recording.bucket).can_view?(recording)
  end

  def editable?
    CategoryPolicy.new(person: person, bucket: recording.bucket).can_edit?(recording)
  end

  def deletable?
    false
  end
end
