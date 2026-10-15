class CreateCsvImportRows < ActiveRecord::Migration[8.1]
  def change
    create_table :csv_import_rows do |t|
      t.references :csv_import, null: false, foreign_key: true
      t.integer :row_number, null: false
      t.jsonb :raw_data, default: {}, null: false
      t.string :row_hash, null: false
      t.boolean :duplicate, default: false, null: false
      t.jsonb :validation_errors
      t.references :imported_recording, null: true, foreign_key: { to_table: :recordings }

      t.timestamps
    end

    add_index :csv_import_rows, [ :csv_import_id, :row_number ], unique: true
    add_index :csv_import_rows, [ :csv_import_id, :row_hash ]
    add_index :csv_import_rows, [ :csv_import_id, :duplicate ]
    add_index :csv_import_rows, :row_hash
  end
end
