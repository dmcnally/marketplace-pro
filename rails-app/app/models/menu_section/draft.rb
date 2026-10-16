class MenuSection::Draft
  include ActiveModel::Model

  attr_accessor :menu, :recording, :name, :description, :image, :remove_image, :revision, :product_ids
  validates :name, presence: true
  validate :valid_products
  validate :consistent_recording

  def self.for(menu, recording)
    new(menu: menu, recording: recording, name: recording.recordable.name, description: recording.recordable.description,
      product_ids: recording.recordable.product_ids, revision: menu.draft_revision)
  end

  def save
    Menu::Structure.new(menu).change!(revision) do
      return false unless valid?

      if recording
        recording.update!(recordable: build_content)
      else
        section = menu.children.create!(bucket: menu.bucket, recordable: build_content)
        Menu::Structure.new(menu).replace_order!(menu.recordable.section_order + [ section.id ])
        self.recording = section
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    errors.merge!(error.record.errors)
    false
  end

  def normalized_product_ids
    Array(product_ids).reject(&:blank?).map(&:to_i)
  end

  def products
    menu.bucket.recordings.products.where("discarded_at IS NULL OR id IN (?)", normalized_product_ids).includes(:recordable).sort_by do |product|
      [ normalized_product_ids.index(product.id) || normalized_product_ids.length, product.recordable.name ]
    end
  end

  private

  def consistent_recording
    return unless recording

    unless recording.menu_section? && recording.parent_id == menu.id && recording.bucket_id == menu.bucket_id && menu.recordable.section_order.include?(recording.id)
      errors.add(:recording, "must be a current section of this menu")
    end
  end

  def valid_products
    ids = normalized_product_ids
    previous = recording&.recordable&.product_ids || []
    allowed = menu.bucket.recordings.products.where("discarded_at IS NULL OR id IN (?)", previous).pluck(:id)
    errors.add(:product_ids, "must belong to this workspace and be active when newly selected") if (ids - allowed).any?
    errors.add(:product_ids, "cannot contain the same product twice") if ids.uniq != ids
  end

  def build_content
    content = MenuSection.new(name: name, description: description, product_ids: normalized_product_ids)
    if image.present?
      content.image.attach(image)
    elsif remove_image != "1" && recording&.recordable&.image&.attached?
      content.image.attach(recording.recordable.image.blob)
    end
    content
  end
end
