class VariantAvailability < ApplicationRecord
  belongs_to :recording
  validates :recording_id, uniqueness: true
  validate :variant_recording

  def withdraw!(reason:)
    change!(available: false, person: Current.person, reason: reason)
  end

  def change!(available:, person:, reason:)
    raise ArgumentError, "Availability must be true or false" unless [ true, false ].include?(available)

    with_lock do
      return if self.available == available

      previous = self.available
      update!(available: available)
      event = recording.events.create!(bucket: recording.bucket, subject: recording.recordable, action: "availability_changed", person: person)
      { "from" => previous ? "available" : "unavailable", "to" => available ? "available" : "unavailable", "reason" => reason }.each do |key, value|
        event.details.create!(key: key, value: value)
      end
    end
  end

  private

  def variant_recording
    errors.add(:recording, "must be a variant") unless recording&.variant?
  end
end
