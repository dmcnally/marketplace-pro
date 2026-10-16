class Product::Draft
  include ActiveModel::Model

  attr_accessor :bucket, :recording, :name, :description, :category_ids, :image,
    :remove_image, :variant_name, :price, :revision

  validates :name, presence: true
  validate :valid_categories
  validate :consistent_recording
  validate :valid_first_variant, unless: :recording

  def self.for(recording)
    new(bucket: recording.bucket, recording: recording, revision: recording.draft_revision,
      **recording.recordable.attributes.symbolize_keys.slice(:name, :description, :category_ids))
  end

  def save
    bucket.with_lock do
      return false unless valid?

      if recording
        recording.with_lock do
          raise Recording::CatalogueEditing::StaleDraft unless revision == recording.draft_revision
          raise Authorization::Denied if recording.discarded?

          recording.update!(recordable: build_content)
        end
      else
        create_product!
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    errors.merge!(error.record.errors)
    false
  end

  def categories
    bucket.recordings.categories.where("discarded_at IS NULL OR id IN (?)", normalized_category_ids).includes(:recordable)
  end

  def publication_status
    Product::Publication.new(recording).status
  end

  def variants
    return [] unless recording

    order = recording.recordable.variant_order
    recording.children.variants.where(id: order).includes(:recordable).sort_by { |variant| order.index(variant.id) }
  end

  private

  def consistent_recording
    return unless recording

    errors.add(:recording, "must be a product in this workspace") unless recording.product? && recording.bucket == bucket
  end

  def valid_first_variant
    variant = Variant.new(name: variant_name.presence || "Default", price: price)
    errors.merge!(variant.errors) unless variant.valid?
  end

  def normalized_category_ids
    Array(category_ids).reject(&:blank?).map(&:to_i).uniq
  end

  def valid_categories
    previous = recording&.recordable&.category_ids || []
    allowed = bucket.recordings.categories.where("discarded_at IS NULL OR id IN (?)", previous).pluck(:id)
    errors.add(:category_ids, "must belong to this workspace and be active when newly assigned") if (normalized_category_ids - allowed).any?
  end

  def build_content
    content = Product.new(name: name, description: description, category_ids: normalized_category_ids,
      variant_order: recording&.recordable&.variant_order || [])
    if image.present?
      content.image.attach(image)
    elsif remove_image != "1" && recording&.recordable&.image&.attached?
      content.image.attach(recording.recordable.image.blob)
    end
    content
  end

  def create_product!
    product = bucket.recordings.create!(recordable: build_content)
    variant = product.children.create!(bucket: bucket, recordable: Variant.new(name: variant_name.presence || "Default", price: price))
    VariantAvailability.create!(recording: variant)
    product.update!(recordable: Product.new(product.recordable.attributes.except("id").merge("variant_order" => [ variant.id ])).tap { |content| content.image.attach(product.recordable.image.blob) if product.recordable.image.attached? })
    self.recording = product
  end
end
