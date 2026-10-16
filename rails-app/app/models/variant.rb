class Variant < ApplicationRecord
  include Recordable

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  def diffable? = true
  def timeline_description(event) = name

  def before_catalogue_archive(recording)
    VariantAvailability.find_by(recording: recording)&.withdraw!(reason: "Variant archived")
  end

  def before_catalogue_restore(recording)
    VariantAvailability.find_by(recording: recording)&.withdraw!(reason: "Variant restored unavailable")
  end
end
