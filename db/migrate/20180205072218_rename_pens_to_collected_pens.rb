class RenamePensToCollectedPens < ActiveRecord::Migration[5.1]
  def change
    rename_table :pens, :collected_pens
  end
end
