class Menu::Preview
  attr_reader :recording

  def initialize(recording)
    @recording = recording
    @structure = Menu::Structure.new(recording)
  end

  def sections
    @sections ||= @structure.sections.filter_map do |section|
      products = recording.bucket.recordings.products.where(id: section.recordable.product_ids).index_by(&:id)
      published = section.recordable.product_ids.filter_map do |id|
        product = Catalogue::PublishedProduct.new(products.fetch(id))
        product if product.visible?
      end
      { recording: section, products: published } if published.any?
    end
  end

  def blockers
    sections.flat_map { |section| section[:products] }.reject(&:published?).map(&:recording).uniq(&:id)
  end
end
