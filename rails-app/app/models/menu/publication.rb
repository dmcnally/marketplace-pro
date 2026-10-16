class Menu::Publication
  class Invalid < StandardError; end

  attr_reader :recording

  def initialize(recording)
    raise ArgumentError, "Expected a menu" unless recording.menu?

    @recording = recording
  end

  def release = Catalogue::Release.find_by(recording: recording)
  def published? = release&.active? || false
  def previous_content = release&.snapshot&.content
  def live_menu = Catalogue::Release.live_menu(recording.bucket)

  def draft_content
    presentation(recording).merge("sections" => Menu::Structure.new(recording).sections.map do |section|
      presentation(section).merge("id" => section.id, "product_ids" => section.recordable.product_ids)
    end)
  end

  def changed?
    previous_content.present? && previous_draft != draft_content
  end

  def status
    return "Never published" unless release

    [ published? ? "Live" : "Unpublished", ("Unpublished changes" if changed?) ].compact.join(" · ")
  end

  def blocking_products
    published_ids = Catalogue::Release.active.where(bucket: recording.bucket, kind: "Product").pluck(:recording_id)
    recording.bucket.recordings.products.where(id: product_ids - published_ids).includes(:recordable)
  end

  def blockers
    messages = []
    messages << "Restore this archived menu before publishing." if recording.discarded?
    messages << "Add at least one section containing a product." if product_ids.empty?
    blocking_products.each { |product| messages << "#{product.recordable.name} has no published version. Publish it or remove it from this draft menu." }
    messages
  end

  def empty_sections
    Menu::Structure.new(recording).sections.select { |section| section.recordable.product_ids.empty? }
  end

  def impact_heading
    current = live_menu
    return "This will become the only live menu" unless current
    return "#{current.snapshot.content.fetch('name')} stays live with this structure" if current.recording_id == recording.id

    "This replaces #{current.snapshot.content.fetch('name')}"
  end

  def replacement_name
    current = live_menu
    current.snapshot.content.fetch("name") if current && current.recording_id != recording.id
  end

  def included_product_names
    recording.bucket.recordings.products.where(id: product_ids).includes(:recordable).map do |product|
      Catalogue::PublishedProduct.new(product).name
    end
  end

  def review_token
    dependencies = Catalogue::Release.where(bucket: recording.bucket, recording_id: product_ids).order(:recording_id).pluck(:recording_id, :snapshot_id, :active)
    Digest::SHA256.hexdigest([ draft_content, recording.draft_revision, recording.discarded?, release&.snapshot_id,
      published?, live_menu&.snapshot_id, dependencies, archived_references ].to_json)
  end

  def publish!(token:)
    change!(token) do
      raise Invalid, blockers.join(" ") if blockers.any?

      draft = draft_content
      content = draft.merge("sections" => draft.fetch("sections").reject { |section| section.fetch("product_ids").empty? }, "draft_sections" => draft.fetch("sections"))
      snapshot = Catalogue::Snapshot.create!(recording: recording, content: content)
      previous = live_menu
      if previous && previous.recording_id != recording.id
        previous.update!(active: false)
        track!(previous.recording, "unpublished", previous.snapshot, "replaced_by_menu_id" => recording.id)
      end
      publication = release || Catalogue::Release.new(recording: recording, bucket: recording.bucket, kind: "Menu")
      publication.update!(snapshot: snapshot, active: true)
      track!(recording, "published", snapshot, "replaced_menu_id" => previous&.recording_id)
    end
  end

  def unpublish!(token:)
    change!(token) do
      raise Invalid, "This menu is not published." unless published?

      release.update!(active: false)
      track!(recording, "unpublished", release.snapshot)
    end
  end

  def revert!(token:)
    change!(token) do
      raise Invalid, "This menu has never been published." unless previous_content
      raise Invalid, "Restore this menu before editing its draft." if recording.discarded?

      restore_content!(previous_draft)
      track!(recording, "reverted", release.snapshot)
    end
  end

  def archived_references
    return [] unless previous_content

    ids = previous_draft.fetch("sections").flat_map { |section| section.fetch("product_ids") }
    recording.bucket.recordings.products.discarded.where(id: ids).includes(:recordable).map { |product| product.recordable.name }
  end

  private

  def product_ids
    draft_content.fetch("sections").flat_map { |section| section.fetch("product_ids") }.uniq
  end

  def previous_draft
    previous_content.except("draft_sections").merge("sections" => previous_content.fetch("draft_sections"))
  end

  def presentation(item)
    content = item.recordable
    { "name" => content.name, "description" => content.description, "image_blob_id" => content.image.blob&.id }
  end

  def change!(token)
    recording.bucket.with_lock do
      recording.with_lock do
        raise Recording::CatalogueEditing::StaleDraft unless token.present? && token == review_token

        yield
      end
    end
  end

  def track!(item, action, snapshot, details = {})
    event = item.events.create!(bucket: item.bucket, subject: item.recordable, action: action, person: Current.person)
    details.merge("snapshot_id" => snapshot.id).compact.each { |key, value| event.details.create!(key: key, value: value.to_s) }
  end

  def restore_content!(content)
    content.fetch("sections").each do |section|
      child = recording.children.menu_sections.find(section.fetch("id"))
      restored = MenuSection.new(section.slice("name", "description", "product_ids"))
      restored.image.attach(ActiveStorage::Blob.find(section["image_blob_id"])) if section["image_blob_id"]
      child.update!(recordable: restored)
    end
    restored = Menu.new(content.slice("name", "description").merge("section_order" => content.fetch("sections").map { |section| section.fetch("id") }))
    restored.image.attach(ActiveStorage::Blob.find(content["image_blob_id"])) if content["image_blob_id"]
    recording.update!(recordable: restored)
  end
end
