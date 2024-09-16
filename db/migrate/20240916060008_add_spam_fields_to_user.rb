class AddSpamFieldsToUser < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :spam, :boolean, default: false
    add_column :users, :spam_reason, :string, default: ""

    safety_assured do
      add_index :users, :spam
      add_index :users, :spam_reason
    end
  end
end
