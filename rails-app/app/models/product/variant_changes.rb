class Product::VariantChanges
  def initialize(product)
    @product = product
  end

  def reorder!(ids, revision:)
    change!(revision) do
      ids = Array(ids).map(&:to_i)
      expected = product.children.variants.pluck(:id)
      raise ArgumentError, "Include every variant exactly once." unless ids.sort == expected.sort

      previous = product.recordable
      content = Product.new(previous.attributes.except("id").merge("variant_order" => ids))
      content.image.attach(previous.image.blob) if previous.image.attached?
      product.update!(recordable: content)
    end
  end

  def assign_allergen!(allergen_id, remove:, revision:)
    change!(revision) do
      scope = product.bucket.recordings.allergens
      scope = scope.kept unless remove
      allergen = scope.find(allergen_id)
      product.children.variants.kept.each do |variant|
        old = variant.recordable
        ids = remove ? old.allergen_ids - [ allergen.id ] : old.allergen_ids | [ allergen.id ]
        next if ids == old.allergen_ids

        variant.update!(recordable: Variant.new(old.attributes.except("id").merge("allergen_ids" => ids)))
      end
    end
  end

  private

  attr_reader :product

  def change!(revision)
    product.bucket.with_lock do
      product.with_lock do
        raise Recording::CatalogueEditing::StaleDraft unless revision == product.draft_revision
        raise Authorization::Denied if product.discarded?

        yield
      end
    end
  end
end
