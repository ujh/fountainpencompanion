class AddUniqueIndexToCollectedInks < ActiveRecord::Migration[5.0]
  def change
    add_index :collected_inks, [:user_id, :brand_name, :line_name, :ink_name], unique: true, name: 'unique_per_user'
  end
end
