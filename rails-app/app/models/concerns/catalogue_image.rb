module CatalogueImage
  extend ActiveSupport::Concern

  included do
    has_one_attached :image
    validate :image_is_supported
  end

  private

  def image_is_supported
    return unless image.attached?

    errors.add(:image, "must be a PNG, JPEG, GIF or WebP") unless %w[image/png image/jpeg image/gif image/webp].include?(image.blob.content_type)
    errors.add(:image, "must be smaller than 10 MB") if image.blob.byte_size > 10.megabytes
  end
end
