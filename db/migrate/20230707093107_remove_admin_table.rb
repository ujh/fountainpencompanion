class RemoveAdminTable < ActiveRecord::Migration[7.0]
  def change
    drop_table :admins
  end
end
