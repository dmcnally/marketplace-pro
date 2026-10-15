class CreateApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table :approvals do |t|
      t.belongs_to :approvable, null: false, polymorphic: true
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :approvals, [ :approvable_type, :approvable_id ], unique: true
  end
end
