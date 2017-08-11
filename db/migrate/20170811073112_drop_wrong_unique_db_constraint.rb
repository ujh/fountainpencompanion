class DropWrongUniqueDbConstraint < ActiveRecord::Migration[5.1]
  def change
    remove_index :collected_inks, column: ["user_id", "brand_name", "line_name", "ink_name"], name: "unique_per_user", unique: true
  end
end
