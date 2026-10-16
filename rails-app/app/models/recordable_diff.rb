class RecordableDiff
  IncompatibleRecordableTypes = Class.new(StandardError)

  def self.previous(recording)
    event = recording.events
      .where(action: "updated")
      .where.not(subject_previous_type: nil, subject_previous_id: nil)
      .order(created_at: :desc, id: :desc)
      .first

    new(current: recording.recordable, previous: event&.subject_previous, event:)
  end

  attr_reader :current, :previous, :event

  def initialize(current:, previous:, event:)
    @current = current
    @previous = previous
    @event = event

    assert_comparable_recordables!
  end

  def changes
    @changes ||= begin
      if previous
        comparison = previous.class.find(previous.id)
        comparison.assign_attributes(current.attributes.slice(*fields))
        comparison.changes.slice(*fields)
      else
        {}
      end
    end
  end

  def fields
    return [] unless current && previous

    current.class.recordable_fields & previous.class.attribute_names
  end

  def image_change
    return unless previous && current.respond_to?(:image) && previous.respond_to?(:image)

    before = previous.image.blob
    after = current.image.blob
    [ before, after ] unless before == after
  end

  private

  def assert_comparable_recordables!
    return unless current && previous
    return if current.class == previous.class

    raise IncompatibleRecordableTypes,
      "Cannot compare #{current.class.name} with #{previous.class.name}"
  end
end
