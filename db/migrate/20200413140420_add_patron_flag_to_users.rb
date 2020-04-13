class AddPatronFlagToUsers < ActiveRecord::Migration[6.0]
  def up
    add_column :users, :patron, :boolean
    change_column_default :users, :patron, false
  end

  def down
    remove_column :users, :patron
  end
end
