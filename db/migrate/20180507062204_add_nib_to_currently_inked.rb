class AddNibToCurrentlyInked < ActiveRecord::Migration[5.2]
  def change
    add_column :currently_inked, :nib, :string, limit: 100, default: ""
  end
end
