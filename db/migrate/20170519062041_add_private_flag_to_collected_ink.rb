class AddPrivateFlagToCollectedInk < ActiveRecord::Migration[5.0]
  def change
    add_column :collected_inks, :private, :boolean, default: true
  end
end
