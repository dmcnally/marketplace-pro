class CreateAllergens < ActiveRecord::Migration[8.1]
  def change
    create_table :catalogue_allergens do |t|
      t.string :name, null: false
      t.text :description
    end
  end
end
