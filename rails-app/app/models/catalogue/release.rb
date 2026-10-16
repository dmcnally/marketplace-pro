class Catalogue::Release < ApplicationRecord
  self.table_name = "catalogue_releases"

  belongs_to :bucket
  belongs_to :recording
  belongs_to :snapshot, class_name: "Catalogue::Snapshot"
  validates :kind, inclusion: { in: %w[Product Menu] }
  validate :consistent_owner

  scope :active, -> { where(active: true) }

  def self.live_menu(bucket)
    active.find_by(bucket: bucket, kind: "Menu")
  end

  def includes_product?(product)
    snapshot.content.fetch("sections", []).any? { |section| section.fetch("product_ids").include?(product.id) }
  end

  private

  def consistent_owner
    errors.add(:recording, "must match the bucket and publication kind") unless recording&.bucket_id == bucket_id && recording&.recordable_type == kind
    errors.add(:snapshot, "must belong to the recording") unless snapshot&.recording_id == recording_id
  end
end
