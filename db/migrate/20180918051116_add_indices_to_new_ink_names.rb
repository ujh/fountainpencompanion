class AddIndicesToNewInkNames < ActiveRecord::Migration[5.2]
  def change
    add_index :new_ink_names, :popular_name
    add_index :new_ink_names, :popular_line_name
  end
end
