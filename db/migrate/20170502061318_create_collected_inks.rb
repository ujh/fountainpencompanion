class CreateCollectedInks < ActiveRecord::Migration[5.0]
  def change
    create_table :collected_inks do |t|
      t.string :kind
      t.integer :ink_id, null: false
      t.foreign_key :inks
      t.integer :user_id, null: false
      t.foreign_key :users
      t.timestamps
    end
  end
end
