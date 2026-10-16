class VariantAvailability < ApplicationRecord
  belongs_to :recording
  validates :recording_id, uniqueness: true
  validate :variant_recording

  def withdraw!(reason:)
    with_lock do
      return unless available?

      update!(available: false)
      event = recording.events.create!(bucket: recording.bucket, subject: recording.recordable, action: "availability_changed", person: Current.person)
      { "from" => "available", "to" => "unavailable", "reason" => reason }.each do |key, value|
        event.details.create!(key: key, value: value)
      end
    end
  end

  private

  def variant_recording
    errors.add(:recording, "must be a variant") unless recording&.variant?
  end
end
