class Product::Publication
  class Invalid < StandardError; end

  attr_reader :recording

  def initialize(recording)
    raise ArgumentError, "Expected a product" unless recording.product?

    @recording = recording
  end

  def release
    Catalogue::Release.find_by(recording: recording)
  end

  def published? = release&.active? || false
  def previous_content = release&.snapshot&.content

  def draft_content
    product = recording.recordable
    { "name" => product.name, "description" => product.description,
      "category_ids" => product.category_ids, "image_blob_id" => product.image.blob&.id,
      "variants" => ordered_variants.map { |variant| variant_content(variant) } }
  end

  def changed?
    previous_content.present? && previous_content != draft_content
  end

  def variant_changes
    before = Array(previous_content&.fetch("variants")).index_by { |variant| variant.fetch("id") }
    after = draft_content.fetch("variants").index_by { |variant| variant.fetch("id") }
    (before.keys | after.keys).filter_map do |id|
      old = before[id]
      current = after[id]
      next if old&.slice("price", "allergens") == current&.slice("price", "allergens")

      { name: (current || old).fetch("name"), before_price: old&.fetch("price"), after_price: current&.fetch("price"),
        before_allergens: allergen_wording(old), after_allergens: allergen_wording(current) }
    end
  end

  def status
    return "Never published" unless release

    [ published? ? "Published" : "Unpublished", ("Unpublished changes" if changed?) ].compact.join(" · ")
  end

  def live_menu
    menu = Catalogue::Release.live_menu(recording.bucket)
    menu if menu&.includes_product?(recording)
  end

  def review_token
    Digest::SHA256.hexdigest([ draft_content, recording.draft_revision, recording.discarded?, archived_references, release&.snapshot_id, published?, Catalogue::Release.live_menu(recording.bucket)&.snapshot_id ].to_json)
  end

  def blockers
    messages = []
    messages << "Restore this archived product before publishing." if recording.discarded?
    messages << "Add at least one active variant with a valid name and price." if ordered_variants.empty? || ordered_variants.any? { |variant| !variant.recordable.valid? }
    messages
  end

  def publish!(token:)
    change!(token) do
      raise Invalid, blockers.join(" ") if blockers.any?

      snapshot = Catalogue::Snapshot.create!(recording: recording, content: draft_content)
      publication = release || Catalogue::Release.new(recording: recording, bucket: recording.bucket, kind: "Product")
      publication.update!(snapshot: snapshot, active: true)
      track!("published", snapshot)
    end
  end

  def unpublish!(token:)
    change!(token) do
      raise Invalid, "Remove this product from every section of the live menu and republish the menu, or unpublish the menu first." if live_menu
      raise Invalid, "This product is not published." unless published?

      release.update!(active: false)
      track!("unpublished", release.snapshot)
    end
  end

  def revert!(token:)
    change!(token) do
      raise Invalid, "This product has never been published." unless previous_content
      raise Invalid, "Restore this product before editing its draft." if recording.discarded?

      restore_content!(previous_content)
      track!("reverted", release.snapshot)
    end
  end

  def archived_references
    return [] unless previous_content

    ids = previous_content.fetch("category_ids") + previous_content.fetch("variants").flat_map { |variant| [ variant.fetch("id") ] + variant.fetch("allergens").map { |allergen| allergen.fetch("id") } }
    recording.bucket.recordings.discarded.where(id: ids).includes(:recordable).map { |item| item.recordable.name }
  end

  private

  def allergen_wording(variant)
    Array(variant&.fetch("allergens")).map { |allergen| [ allergen.fetch("name"), allergen["description"].presence ].compact.join(": ") }.join("; ")
  end

  def ordered_variants
    variants = recording.children.variants.kept.where(id: recording.recordable.variant_order).includes(:recordable).index_by(&:id)
    recording.recordable.variant_order.filter_map { |id| variants[id] }
  end

  def variant_content(variant)
    content = variant.recordable
    allergens = recording.bucket.recordings.allergens.where(id: content.allergen_ids).includes(:recordable).index_by(&:id)
    { "id" => variant.id, "name" => content.name, "price" => content.price.to_s("F"),
      "allergens" => content.allergen_ids.map do |id|
        allergen = allergens.fetch(id).recordable
        { "id" => id, "name" => allergen.name, "description" => allergen.description }
      end }
  end

  def change!(token)
    recording.bucket.with_lock do
      recording.with_lock do
        raise Recording::CatalogueEditing::StaleDraft unless token.present? && token == review_token

        yield
      end
    end
  end

  def track!(action, snapshot)
    event = recording.events.create!(bucket: recording.bucket, subject: recording.recordable, action: action, person: Current.person)
    event.details.create!(key: "snapshot_id", value: snapshot.id.to_s)
  end

  def restore_content!(content)
    content.fetch("variants").each do |variant|
      child = recording.children.variants.find(variant.fetch("id"))
      child.update!(recordable: Variant.new(name: variant.fetch("name"), price: variant.fetch("price"), allergen_ids: variant.fetch("allergens").map { |allergen| allergen.fetch("id") }))
    end
    product = Product.new(content.slice("name", "description", "category_ids").merge("variant_order" => content.fetch("variants").map { |variant| variant.fetch("id") }))
    product.image.attach(ActiveStorage::Blob.find(content["image_blob_id"])) if content["image_blob_id"]
    recording.update!(recordable: product)
  end
end
