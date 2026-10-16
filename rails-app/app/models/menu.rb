class Menu < ApplicationRecord
  include Recordable
  include CatalogueImage

  validates :name, presence: true

  def diffable? = true
  def timeline_description(event) = name

  def before_catalogue_archive(recording)
    release = Catalogue::Release.active.find_by(recording: recording)
    return unless release

    release.update!(active: false)
    event = recording.events.create!(bucket: recording.bucket, subject: recording.recordable, action: "unpublished", person: Current.person)
    event.details.create!(key: "reason", value: "Menu archived")
  end
end
