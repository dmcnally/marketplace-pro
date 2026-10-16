class ProductPolicy < RecordablePolicy
  def can_create? = person.editor_of?(bucket)

  def can_view?(recording)
    assert_recordable!(recording)
    recording.bucket == bucket && can_create?
  end

  def can_edit?(recording)
    can_view?(recording) && recording.kept?
  end

  def can_publish?(recording) = can_edit?(recording)
  def can_unpublish?(recording) = can_edit?(recording) && recording.catalogue_published?
  def can_revert?(recording) = can_edit?(recording) && recording.catalogue_previously_published?
  def can_archive?(recording) = can_edit?(recording)
  def can_restore?(recording) = can_view?(recording) && recording.discarded?

  def can_archive_variant?(product, variant)
    can_edit?(product) && owns_variant?(product, variant) && variant.kept?
  end

  def can_restore_variant?(product, variant)
    can_view?(product) && owns_variant?(product, variant) && variant.discarded?
  end

  private

  def owns_variant?(product, variant)
    variant.variant? && variant.parent_id == product.id && variant.bucket_id == bucket.id
  end
end
