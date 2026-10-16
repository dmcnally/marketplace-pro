class CreateMenusAndSections < ActiveRecord::Migration[8.1]
  def change
    create_table :menus do |t|
      t.string :name, null: false
      t.text :description
      t.bigint :section_order, array: true, null: false, default: []
    end

    create_table :menu_sections do |t|
      t.string :name, null: false
      t.text :description
      t.bigint :product_ids, array: true, null: false, default: []
    end
  end
end
