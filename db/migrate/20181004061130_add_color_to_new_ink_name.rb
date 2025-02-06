class AddColorToNewInkName < ActiveRecord::Migration[5.2]
  def change
    add_column :new_ink_names, :color, :string, limit: 7, default: "", null: false
  end
end
