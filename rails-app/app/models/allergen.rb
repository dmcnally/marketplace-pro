class Allergen < ApplicationRecord
  self.table_name = "catalogue_allergens"

  include Recordable

  validates :name, presence: true

  def diffable?
    true
  end

  def timeline_description(event)
    name
  end
end
