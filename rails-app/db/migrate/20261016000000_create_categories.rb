class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :catalogue_categories do |t|
      t.string :name, null: false
      t.text :description
    end
  end
end
