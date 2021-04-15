class AddIsBotFlagToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :bot, :boolean, default: false
  end
end
