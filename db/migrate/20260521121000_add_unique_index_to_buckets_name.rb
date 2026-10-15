class AddUniqueIndexToBucketsName < ActiveRecord::Migration[8.1]
  def change
    add_index :buckets, :name, unique: true
  end
end
