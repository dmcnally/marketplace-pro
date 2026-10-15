class DefaultRecordingPolicy
  def initialize(person:, recording:)
    @person = person
    @recording = recording
  end

  def editable?
    person.editor_of?(recording.bucket)
  end

  def deletable?
    person.admin_of?(recording.bucket) || recording.creator == person
  end

  def viewable?
    person.viewer_of?(recording.bucket)
  end

  private

  attr_reader :person, :recording
end
