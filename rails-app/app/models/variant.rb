class Variant < ApplicationRecord
  include Recordable

  validates :name, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  def diffable? = true
  def timeline_description(event) = name
end
