class CreatePublications < ActiveRecord::Migration[8.1]
  def change
    create_table :publications do |t|
      t.references :publishable,
                   null: false,
                   polymorphic: true,
                   index: { unique: true }

      t.timestamps
    end
  end
end
