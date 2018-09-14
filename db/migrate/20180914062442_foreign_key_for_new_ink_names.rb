class ForeignKeyForNewInkNames < ActiveRecord::Migration[5.2]
  def change
    add_column :collected_inks, :new_ink_name_id, :integer
    add_foreign_key :collected_inks, :new_ink_names
  end
end
