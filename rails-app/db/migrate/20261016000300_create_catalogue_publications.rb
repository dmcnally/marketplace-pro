class CreateCataloguePublications < ActiveRecord::Migration[8.1]
  def change
    create_table :catalogue_snapshots do |t|
      t.references :recording, null: false, foreign_key: true
      t.jsonb :content, null: false
      t.datetime :created_at, null: false
    end

    create_table :catalogue_releases do |t|
      t.references :bucket, null: false, foreign_key: true
      t.references :recording, null: false, foreign_key: true, index: { unique: true }
      t.references :snapshot, null: false, foreign_key: { to_table: :catalogue_snapshots }
      t.string :kind, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :catalogue_releases, :bucket_id, unique: true, where: "kind = 'Menu' AND active", name: "one_active_menu_per_bucket"
  end
end
