class Product::Copy
  include ActiveModel::Model

  attr_accessor :source, :name, :revision
  attr_reader :recording

  validates :name, presence: true
  validate :copyable_content

  def save
    raise ArgumentError, "Expected a product" unless source&.product?

    source.bucket.with_lock do
      source.with_lock do
        raise Recording::CatalogueEditing::StaleDraft unless revision.present? && revision == source.draft_revision
        raise Authorization::Denied if source.discarded?
        return false unless valid?

        copy = source.bucket.recordings.create!(recordable: copied_content([]))
        variants = source_variants.map { |variant| copy_variant(copy, variant) }
        copy.update!(recordable: copied_content(variants.map(&:id)))
        track_copy(copy, source)
        @recording = copy
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    errors.merge!(error.record.errors)
    false
  end

  private

  def source_variants
    order = source.recordable.variant_order
    source.children.variants.kept.where(id: order).includes(:recordable).sort_by { |variant| order.index(variant.id) }
  end

  def copyable_content
    return errors.add(:source, "must be a product") unless source&.product?

    errors.add(:base, "Restore at least one variant before copying this product.") if source_variants.empty?
    category_ids = source.recordable.category_ids
    allergen_ids = source_variants.flat_map { |variant| variant.recordable.allergen_ids }.uniq
    if (category_ids - source.bucket.recordings.categories.kept.pluck(:id)).any? || (allergen_ids - source.bucket.recordings.allergens.kept.pluck(:id)).any?
      errors.add(:base, "This draft references archived or unavailable categories or allergens. Restore them or remove their assignments before copying.")
    end
  end

  def copied_content(order)
    content = Product.new(source.recordable.attributes.except("id").merge("name" => name, "variant_order" => order))
    content.image.attach(source.recordable.image.blob) if source.recordable.image.attached?
    content
  end

  def copy_variant(copy, source_variant)
    variant = copy.children.create!(bucket: source.bucket, recordable: Variant.new(source_variant.recordable.attributes.except("id")))
    VariantAvailability.create!(recording: variant, available: false)
    track_copy(variant, source_variant)
    variant
  end

  def track_copy(copy, original)
    event = copy.events.create!(bucket: source.bucket, subject: copy.recordable, action: "copied", person: Current.person)
    event.details.create!(key: "source_recording_id", value: original.id)
  end
end
