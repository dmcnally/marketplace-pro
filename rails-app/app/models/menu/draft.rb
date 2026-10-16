class Menu::Draft
  include ActiveModel::Model

  attr_accessor :bucket, :recording, :name, :description, :image, :remove_image, :revision
  validates :name, presence: true
  validate :consistent_recording

  def self.for(recording)
    new(bucket: recording.bucket, recording: recording, name: recording.recordable.name,
      description: recording.recordable.description, revision: recording.draft_revision)
  end

  def save
    bucket.with_lock do
      return false unless valid?

      if recording
        recording.with_lock do
          raise Recording::CatalogueEditing::StaleDraft unless revision.present? && revision == recording.draft_revision
          raise Authorization::Denied if recording.discarded?

          recording.update!(recordable: build_content)
        end
      else
        self.recording = bucket.recordings.create!(recordable: build_content)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    errors.merge!(error.record.errors)
    false
  end

  def sections
    return [] unless recording

    structure.sections
  end

  def structure
    Menu::Structure.new(recording)
  end

  def publication_status
    Menu::Publication.new(recording).status
  end

  private

  def consistent_recording
    errors.add(:recording, "must be a menu in this workspace") if recording && (!recording.menu? || recording.bucket != bucket)
  end

  def build_content
    content = Menu.new(name: name, description: description, section_order: recording&.recordable&.section_order || [])
    if image.present?
      content.image.attach(image)
    elsif remove_image != "1" && recording&.recordable&.image&.attached?
      content.image.attach(recording.recordable.image.blob)
    end
    content
  end
end
