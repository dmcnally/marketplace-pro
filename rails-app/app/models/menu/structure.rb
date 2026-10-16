class Menu::Structure
  attr_reader :recording

  def initialize(recording)
    raise ArgumentError, "Expected a menu" unless recording.menu?

    @recording = recording
  end

  def sections
    indexed = recording.children.menu_sections.where(id: recording.recordable.section_order).includes(:recordable).index_by(&:id)
    recording.recordable.section_order.map { |id| indexed.fetch(id) }
  end

  def other_sections(product, except:)
    sections.select { |section| section.id != except.id && section.recordable.product_ids.include?(product.id) }.map { |section| section.recordable.name }
  end

  def products_for(section)
    products = recording.bucket.recordings.products.where(id: section.recordable.product_ids).includes(:recordable).index_by(&:id)
    section.recordable.product_ids.map do |id|
      product = products.fetch(id)
      { recording: product, other_sections: other_sections(product, except: section), status: Product::Publication.new(product).status }
    end
  end

  def reorder!(ids, revision:)
    change!(revision) do
      order = ids.map(&:to_i)
      raise ArgumentError, "Include every section exactly once." unless order.sort == recording.recordable.section_order.sort

      replace_order!(order)
    end
  end

  def remove!(section, revision:)
    change!(revision) do
      raise ActiveRecord::RecordNotFound unless section.parent_id == recording.id && recording.recordable.section_order.include?(section.id)

      replace_order!(recording.recordable.section_order - [ section.id ])
    end
  end

  def change!(revision)
    recording.bucket.with_lock do
      recording.with_lock do
        raise Recording::CatalogueEditing::StaleDraft unless revision.present? && revision == recording.draft_revision
        raise Authorization::Denied if recording.discarded?

        yield
      end
    end
  end

  def replace_order!(order)
    previous = recording.recordable
    content = Menu.new(previous.attributes.except("id").merge("section_order" => order))
    content.image.attach(previous.image.blob) if previous.image.attached?
    recording.update!(recordable: content)
  end
end
