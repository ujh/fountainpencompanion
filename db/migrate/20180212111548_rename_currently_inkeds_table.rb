class RenameCurrentlyInkedsTable < ActiveRecord::Migration[5.1]
  def change
    rename_table :currently_inkeds, :currently_inked
  end
end
