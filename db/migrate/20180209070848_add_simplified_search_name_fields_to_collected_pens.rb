class AddSimplifiedSearchNameFieldsToCollectedPens < ActiveRecord::Migration[5.1]
  def change
    add_column :collected_pens, :search_name, :string
    CollectedPen.find_each {|cp| cp.save }
  end
end
