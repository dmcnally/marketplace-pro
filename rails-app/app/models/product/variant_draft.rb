class Product::VariantDraft
  include ActiveModel::Model

  attr_accessor :product, :recording, :name, :price, :allergen_ids, :source_id, :revision

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validate :valid_assignments
  validate :consistent_recording

  def self.for(product, recording)
    new(product: product, recording: recording, revision: product.draft_revision,
      **recording.recordable.attributes.symbolize_keys.slice(:name, :price, :allergen_ids))
  end

  def save
    product.bucket.with_lock do
      return false unless valid?

      product.with_lock do
        raise Recording::CatalogueEditing::StaleDraft unless revision == product.draft_revision
        raise Authorization::Denied if product.discarded? || recording&.discarded?

        content = Variant.new(name: name, price: price, allergen_ids: selected_allergen_ids)
        if recording
          recording.update!(recordable: content)
        else
          created_variant = product.children.create!(bucket: product.bucket, recordable: content)
          VariantAvailability.create!(recording: created_variant)
          update_order!(created_variant)
          self.recording = created_variant
        end
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    errors.merge!(error.record.errors)
    false
  end

  def allergens
    product.bucket.recordings.allergens.where("discarded_at IS NULL OR id IN (?)", selected_allergen_ids).includes(:recordable)
  end

  def sources
    product.children.variants.kept.where(id: product.recordable.variant_order).includes(:recordable).order(:id)
  end

  private

  def consistent_recording
    return unless recording

    unless recording.variant? && recording.parent_id == product.id && recording.bucket_id == product.bucket_id && product.recordable.variant_order.include?(recording.id)
      errors.add(:recording, "must be a current variant of this product")
    end
  end

  def selected_allergen_ids
    return source.recordable.allergen_ids if recording.nil? && source

    Array(allergen_ids).reject(&:blank?).map(&:to_i).uniq
  end

  def source
    sources.find_by(id: source_id) if source_id.present?
  end

  def valid_assignments
    if recording.nil? && source.nil?
      errors.add(:source_id, "must be an active variant of this product")
    end
    previous = recording&.recordable&.allergen_ids || []
    allowed = product.bucket.recordings.allergens.where("discarded_at IS NULL OR id IN (?)", previous).pluck(:id)
    errors.add(:allergen_ids, "must belong to this workspace and be active when newly assigned") if (selected_allergen_ids - allowed).any?
  end

  def update_order!(variant)
    previous = product.recordable
    content = Product.new(previous.attributes.except("id").merge("variant_order" => previous.variant_order + [ variant.id ]))
    content.image.attach(previous.image.blob) if previous.image.attached?
    product.update!(recordable: content)
  end
end
