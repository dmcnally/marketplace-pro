class Product::Catalogue
  STATES = { "All publication states" => "", "Published" => "published", "Unpublished" => "unpublished", "Never published" => "never_published", "Unpublished changes" => "changed" }.freeze

  attr_reader :bucket, :query, :category_id, :publication_state

  def initialize(bucket:, query: nil, category_id: nil, publication_state: nil)
    @bucket = bucket
    @query = query.to_s.strip
    @category_id = category_id.to_s
    @publication_state = publication_state.to_s
  end

  def categories
    @categories ||= bucket.recordings.categories.includes(:recordable).sort_by { |category| category.recordable.name.downcase }
  end

  def invalid_filter?
    !STATES.value?(publication_state) || (category_id.present? && categories.none? { |category| category.id.to_s == category_id })
  end

  def rows
    @rows ||= invalid_filter? ? [] : products.filter_map do |product|
      publication = Product::Publication.new(product)
      next unless matches_publication?(publication)

      variants = Product::Draft.for(product).variants.select(&:kept?)
      { recording: product, status: publication.status, variant_count: variants.size, minimum_price: variants.map { |variant| variant.recordable.price }.min }
    end
  end

  private

  def products
    scope = bucket.recordings.products.kept.joins("INNER JOIN products ON products.id = recordings.recordable_id").includes(:recordable)
    scope = scope.where("products.name ILIKE ?", "%#{Product.sanitize_sql_like(query)}%") if query.present?
    scope = scope.where("? = ANY(products.category_ids)", category_id.to_i) if category_id.present?
    scope.order(Arel.sql("LOWER(products.name)"), :id)
  end

  def matches_publication?(publication)
    case publication_state
    when "published" then publication.published?
    when "unpublished" then publication.release.present? && !publication.published?
    when "never_published" then publication.release.nil?
    when "changed" then publication.changed?
    else true
    end
  end
end
