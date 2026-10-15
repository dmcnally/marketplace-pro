class CreateCsvImports < ActiveRecord::Migration[8.1]
  def change
    create_table :csv_imports do |t|
      t.references :bucket, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :people }
      t.string :import_type, limit: 50
      t.string :status, null: false, default: "pending", limit: 11
      t.string :failure_class
      t.text :failure_message

      t.timestamps
    end
  end
end
