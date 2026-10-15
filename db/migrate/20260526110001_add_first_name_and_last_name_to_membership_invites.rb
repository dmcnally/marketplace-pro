class AddFirstNameAndLastNameToMembershipInvites < ActiveRecord::Migration[8.1]
  def change
    add_column :membership_invites, :first_name, :string
    add_column :membership_invites, :last_name, :string
  end
end
