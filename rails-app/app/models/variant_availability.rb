class VariantAvailability < ApplicationRecord
  belongs_to :recording
  validates :recording_id, uniqueness: true
  validate :variant_recording

  private

  def variant_recording
    errors.add(:recording, "must be a variant") unless recording&.variant?
  end
end
