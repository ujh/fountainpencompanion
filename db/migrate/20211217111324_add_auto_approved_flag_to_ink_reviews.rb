class AddAutoApprovedFlagToInkReviews < ActiveRecord::Migration[6.1]
  def change
    add_column :ink_reviews, :auto_approved, :boolean, default: false
  end
end
