class AddMakerToCollectedInk < ActiveRecord::Migration[5.2]
  def change
    add_column :collected_inks, :maker, :text, default: ""
  end
end
