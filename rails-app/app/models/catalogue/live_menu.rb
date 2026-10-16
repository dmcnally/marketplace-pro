class Catalogue::LiveMenu
  attr_reader :release

  def initialize(bucket)
    @bucket = bucket
    @release = Catalogue::Release.live_menu(bucket)
  end

  def sections
    return [] unless release && release.recording.kept?

    release.snapshot.content.fetch("sections").filter_map do |section|
      products = @bucket.recordings.products.kept.where(id: section.fetch("product_ids")).index_by(&:id)
      visible = section.fetch("product_ids").filter_map do |id|
        next unless products[id]

        product = Catalogue::PublishedProduct.new(products.fetch(id))
        product if product.published? && product.visible?
      end
      section.merge("products" => visible) if visible.any?
    end
  end

  def products
    sections.flat_map { |section| section.fetch("products") }.uniq { |product| product.recording.id }
  end
end
