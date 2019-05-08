class CreateUsageRecords < ActiveRecord::Migration[5.2]
  def change
    create_table :usage_records do |t|
      t.references :currently_inked, foreign_key: true, null: false
      t.date :used_on, null: false
      t.timestamps
    end
    add_index :usage_records, [:currently_inked_id, :used_on], unique: true
  end
end
