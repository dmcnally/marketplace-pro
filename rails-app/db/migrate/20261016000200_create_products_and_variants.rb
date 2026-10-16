class CreateProductsAndVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :buckets, :currency, :string, null: false, default: "GBP"

    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.bigint :category_ids, array: true, default: [], null: false
      t.bigint :variant_order, array: true, default: [], null: false
    end

    create_table :variants do |t|
      t.string :name, null: false
      t.decimal :price, precision: 12, scale: 2, null: false
      t.bigint :allergen_ids, array: true, default: [], null: false
    end
    add_check_constraint :variants, "price >= 0", name: "variants_nonnegative_price"

    create_table :variant_availabilities do |t|
      t.references :recording, null: false, foreign_key: true, index: { unique: true }
      t.boolean :available, null: false, default: false
      t.timestamps
    end
  end
end
