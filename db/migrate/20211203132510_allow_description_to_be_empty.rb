class AllowDescriptionToBeEmpty < ActiveRecord::Migration[6.1]
  def change
    change_column_null :ink_reviews, :description, true
  end
end
