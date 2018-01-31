class AddColorToCollectedInk < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_inks, :color, :string, limit: 7
  end
end
