class AddExtraDataToInkReview < ActiveRecord::Migration[8.0]
  def change
    add_column :ink_reviews, :extra_data, :jsonb, default: {}
  end
end
