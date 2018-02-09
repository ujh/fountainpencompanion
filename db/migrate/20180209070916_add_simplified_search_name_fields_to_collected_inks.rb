class AddSimplifiedSearchNameFieldsToCollectedInks < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_inks, :search_name, :string
    CollectedInk.find_each {|ci| ci.save }
  end
end
