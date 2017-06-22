class AddLineIdToInk < ActiveRecord::Migration[5.0]
  def change
    add_column :inks, :line_id, :integer
    add_foreign_key :inks, :lines
  end
end
