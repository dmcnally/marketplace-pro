class CreateMembershipInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :membership_invites do |t|
      t.references :bucket, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :people }
      t.references :accepted_by, foreign_key: { to_table: :people }
      t.string :email_address, null: false
      t.integer :role, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :membership_invites, :token_digest, unique: true
    add_index :membership_invites,
              [ :bucket_id, :email_address ],
              unique: true,
              where: "accepted_at IS NULL AND revoked_at IS NULL"
  end
end
