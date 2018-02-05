class AddLengthLimitToCollectedPensFields < ActiveRecord::Migration[5.1]
  def change
    change_column :collected_pens, :brand, :string, limit: 100, null: false
    change_column :collected_pens, :model, :string, limit: 100, null: false
  end
end
