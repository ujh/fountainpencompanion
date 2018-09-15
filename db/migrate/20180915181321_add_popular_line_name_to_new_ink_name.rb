class AddPopularLineNameToNewInkName < ActiveRecord::Migration[5.2]
  def change
    add_column :new_ink_names, :popular_line_name, :text, default: ''
  end
end
