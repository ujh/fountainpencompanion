class AddInkedOnToCurrentlyInked < ActiveRecord::Migration[5.1]
  def change
    add_column :currently_inked, :inked_on, :date
    execute "UPDATE currently_inked SET inked_on = created_at"
    change_column :currently_inked, :inked_on, :date, null: false
  end
end
