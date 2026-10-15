class AddPersonToApprovals < ActiveRecord::Migration[8.1]
  def change
    add_reference :approvals, :person, foreign_key: true
  end
end
