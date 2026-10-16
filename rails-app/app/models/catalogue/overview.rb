class Catalogue::Overview
  def initialize(bucket)
    @bucket = bucket
    @live_menu = Catalogue::LiveMenu.new(bucket)
  end

  def menu_name = @live_menu.release&.snapshot&.content&.fetch("name")
  def published? = @live_menu.release.present?

  def products
    @products ||= @live_menu.products.map do |product|
      records = product.recording.children.variants.index_by(&:id)
      states = VariantAvailability.where(recording: records.values).pluck(:recording_id, :available).to_h
      variants = product.variants.map do |variant|
        { recording: records.fetch(variant.fetch("id")), name: variant.fetch("name"), price: variant.fetch("price"),
          allergens: variant.fetch("allergens").map { |allergen| [ allergen.fetch("name"), allergen["description"].presence ].compact.join(": ") }.join("; ").presence || "No allergens listed",
          available: states.fetch(variant.fetch("id"), false) }
      end
      { recording: product.recording, name: product.name, variants: variants, available_count: variants.count { |variant| variant[:available] } }
    end
  end
end
