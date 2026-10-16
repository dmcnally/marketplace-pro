class Category < ApplicationRecord
  self.table_name = "catalogue_categories"

  include Recordable

  validates :name, presence: true

  def diffable?
    true
  end

  def timeline_description(event)
    name
  end
end
