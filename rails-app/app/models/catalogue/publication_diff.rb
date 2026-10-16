class Catalogue::PublicationDiff
  def initialize(event)
    @event = event
  end

  def available?
    @event.action == "published" && snapshot.present?
  end

  def first_publication? = previous_snapshot.nil?

  def changes
    return [] unless available?

    before = fields(previous_snapshot&.content)
    after = fields(snapshot.content)
    (before.keys | after.keys).filter_map do |key|
      next if before[key] == after[key]

      { field: label(key), before: display(key, before[key], previous_snapshot, previous_event), after: display(key, after[key], snapshot, @event) }
    end
  end

  private

  def snapshot
    @snapshot ||= snapshot_for(@event)
  end

  def previous_event
    return @previous_event if defined?(@previous_event)

    @previous_event = @event.eventable.events.where(action: "published")
      .where("created_at < :time OR (created_at = :time AND id < :id)", time: @event.created_at, id: @event.id)
      .order(created_at: :desc, id: :desc).first
  end

  def previous_snapshot
    return @previous_snapshot if defined?(@previous_snapshot)

    @previous_snapshot = snapshot_for(previous_event)
  end

  def snapshot_for(event)
    return unless event

    id = event.details.find { |detail| detail.key == "snapshot_id" }&.value
    Catalogue::Snapshot.find_by(id: id, recording_id: event.eventable_id)
  end

  def fields(content)
    return {} unless content

    values = content.slice("name", "description", "image_blob_id").transform_keys { |key| [ key ] }
    values[[ "categories" ]] = content["category_ids"] if content.key?("category_ids")
    %w[variants sections].each do |collection|
      next unless content.key?(collection)

      items = content.fetch(collection)
      values[[ "#{collection}_order" ]] = items.map { |item| item.fetch("id") }
      items.each do |item|
        item.except("id").each do |key, value|
          values[[ collection, item.fetch("id"), key ]] = value
        end
      end
    end
    values
  end

  def display(key, value, version, event)
    return if value.nil?
    return names(value, event) if %w[categories product_ids].include?(key.last)
    if %w[variants_order sections_order].include?(key.last)
      return version.content.fetch(key.last.delete_suffix("_order")).map { |item| item.fetch("name") }.join(", ")
    end
    if key.last == "allergens"
      return value.map { |allergen| [ allergen.fetch("name"), allergen["description"].presence ].compact.join(": ") }.join("; ")
    end

    value
  end

  def names(ids, event)
    records = event.bucket.recordings.where(id: ids).index_by(&:id)
    Array(ids).map { |id| records[id]&.subject_at(event)&.name || "Record #{id}" }.join(", ")
  end

  def label(key)
    field = { "image_blob_id" => "Image", "product_ids" => "Products", "variants_order" => "Variant order", "sections_order" => "Section order" }.fetch(key.last) { key.last.humanize }
    return field if key.one?

    collection, id = key
    item = [ snapshot, previous_snapshot ].compact.flat_map { |version| version.content.fetch(collection, []) }.find { |entry| entry.fetch("id") == id }
    "#{collection.singularize.humanize}: #{item.fetch('name')} · #{field}"
  end
end
