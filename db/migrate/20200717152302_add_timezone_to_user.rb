class AddTimezoneToUser < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :timezone, :string
  end
end
