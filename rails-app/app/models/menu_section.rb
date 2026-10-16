class MenuSection < ApplicationRecord
  include Recordable
  include CatalogueImage

  validates :name, presence: true
  validate :unique_products

  def diffable? = true
  def timeline_description(event) = name

  private

  def unique_products
    errors.add(:product_ids, "cannot contain the same product twice") if product_ids.uniq != product_ids
  end
end
