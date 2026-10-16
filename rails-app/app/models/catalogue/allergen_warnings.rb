class Catalogue::AllergenWarnings
  def initialize(bucket)
    @live_menu = Catalogue::LiveMenu.new(bucket)
  end

  def entries
    products.filter_map do |product|
      changes = allergen_changes(product)
      { recording: product.recording, name: product.name, changes: changes } if changes.any?
    end
  end

  def affected_by(allergen)
    products.select do |product|
      variants = product.variants + Product::Publication.new(product.recording).draft_content.fetch("variants")
      variants.any? { |variant| variant.fetch("allergens").any? { |item| item.fetch("id") == allergen.id } }
    end
  end

  def menu_name
    @live_menu.release&.snapshot&.content&.fetch("name")
  end

  private

  def products
    @products ||= @live_menu.sections.flat_map { |section| section.fetch("products") }.uniq { |product| product.recording.id }
  end

  def allergen_changes(product)
    before = product.variants.index_by { |variant| variant.fetch("id") }
    after = Product::Publication.new(product.recording).draft_content.fetch("variants").index_by { |variant| variant.fetch("id") }
    (before.keys | after.keys).filter_map do |id|
      previous = allergens(before[id])
      current = allergens(after[id])
      next if previous == current

      { variant_name: (after[id] || before[id]).fetch("name"), before: wording(previous), after: wording(current) }
    end
  end

  def allergens(variant)
    Array(variant&.fetch("allergens")).sort_by { |allergen| allergen.fetch("id") }
  end

  def wording(allergens)
    return "None" if allergens.empty?

    allergens.map { |allergen| [ allergen.fetch("name"), allergen["description"].presence ].compact.join(": ") }.join("; ")
  end
end
