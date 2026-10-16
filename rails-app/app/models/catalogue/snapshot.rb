class Catalogue::Snapshot < ApplicationRecord
  include Immutable
  self.table_name = "catalogue_snapshots"

  belongs_to :recording
  validates :content, presence: true
end
