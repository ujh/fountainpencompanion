class AddBotReasonToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :bot_reason, :string
  end
end
