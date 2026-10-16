class Catalogue::PublishedProduct
  attr_reader :recording, :content

  def initialize(recording)
    raise ArgumentError, "Expected a product" unless recording.product?

    @recording = recording
    @content = Catalogue::Release.active.find_by(recording: recording)&.snapshot&.content
  end

  def published? = content.present?
  def name = content&.fetch("name") || recording.recordable.name
  def description = content&.fetch("description")
  def image = ActiveStorage::Blob.find_by(id: content&.fetch("image_blob_id"))

  def variants
    return [] unless published? && recording.kept?

    ids = recording.children.variants.kept.pluck(:id)
    content.fetch("variants").select { |variant| ids.include?(variant.fetch("id")) }
  end

  def visible?
    recording.kept? && (!published? || variants.any?)
  end

  def availability_for(variant)
    VariantAvailability.find_by(recording_id: variant.fetch("id"))&.available? ? "Available" : "Sold out"
  end
end
