class Product < ApplicationRecord
  include Recordable
  include CatalogueImage

  validates :name, presence: true

  def diffable? = true
  def timeline_description(event) = name

  def before_catalogue_archive(recording)
    VariantAvailability.where(recording: recording.children.variants).order(:id).each { |availability| availability.withdraw!(reason: "Product archived") }
  end

  def before_catalogue_restore(recording)
    VariantAvailability.where(recording: recording.children.variants).order(:id).each { |availability| availability.withdraw!(reason: "Product restored unavailable") }
  end
end
