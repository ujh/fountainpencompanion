class AddInkBrandAssociationToCollectedInk < ActiveRecord::Migration[5.2]
  def change
    add_reference :collected_inks, :ink_brand, foreign_key: true, null: true
  end
end
