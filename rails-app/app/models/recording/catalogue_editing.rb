module Recording::CatalogueEditing
  extend ActiveSupport::Concern

  class StaleDraft < StandardError; end

  def draft_revision
    updated_at.iso8601(6)
  end

  def catalogue_published?
    Catalogue::Release.active.exists?(recording: self)
  end

  def catalogue_previously_published?
    Catalogue::Release.exists?(recording: self)
  end

  def revise_content!(attributes, revision:)
    with_catalogue_lock do
      assert_draft_revision!(revision)
      raise Authorization::Denied if discarded?

      update!(recordable: recordable.class.new(attributes))
    end
  end

  def archive_content!(revision:)
    with_catalogue_lock do
      assert_draft_revision!(revision)
      discard!
    end
  end

  def restore_content!(revision:)
    with_catalogue_lock do
      assert_draft_revision!(revision)
      if discarded?
        restore!
        events.create!(bucket: bucket, subject: recordable, action: "restored", person: Current.person)
      end
    end
  end

  private

  def with_catalogue_lock(&block)
    bucket.with_lock { with_lock(&block) }
  end

  def assert_draft_revision!(revision)
    raise StaleDraft unless revision.present? && revision == draft_revision
  end
end
