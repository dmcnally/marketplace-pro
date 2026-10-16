class Catalogue::Availability
  def initialize(bucket:, person:)
    @bucket = bucket
    @person = person
  end

  def set_variant!(variant, available:)
    change!(available) do
      raise Authorization::Denied unless can_change_variant?(variant)

      set!(variant.id, available)
    end
  end

  def set_product!(product, available:)
    change!(available) do
      raise Authorization::Denied unless can_change_product?(product)

      published = Catalogue::LiveMenu.new(@bucket).products.find { |item| item.recording.id == product.id }
      published.variants.each { |variant| set!(variant.fetch("id"), available) }
    end
  end

  def can_view? = @person.viewer_of?(@bucket)

  def can_change_product?(recording)
    can_view? && recording.product? && recording.bucket_id == @bucket.id && published_product(recording.id).present?
  end

  def can_change_variant?(recording)
    return false unless can_view? && recording.variant? && recording.bucket_id == @bucket.id

    published_product(recording.parent_id)&.variants&.any? { |variant| variant.fetch("id") == recording.id } || false
  end

  private

  def published_product(id)
    Catalogue::LiveMenu.new(@bucket).products.find { |product| product.recording.id == id }
  end

  def change!(available)
    raise ArgumentError, "Availability must be true or false" unless [ true, false ].include?(available)

    @bucket.with_lock do
      yield
    end
  end

  def set!(variant_id, available)
    VariantAvailability.find_by!(recording_id: variant_id).change!(available: available, person: @person, reason: "Staff availability change")
  end
end
