class AddNameToUser < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :name, :string, limit: 100
  end
end
