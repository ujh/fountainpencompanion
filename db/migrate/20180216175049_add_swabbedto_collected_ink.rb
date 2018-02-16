class AddSwabbedtoCollectedInk < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_inks, :swabbed, :boolean, default: false, null: false
  end
end
