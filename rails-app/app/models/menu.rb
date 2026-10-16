class Menu < ApplicationRecord
  include Recordable
  include CatalogueImage

  validates :name, presence: true

  def diffable? = true
  def timeline_description(event) = name
end
