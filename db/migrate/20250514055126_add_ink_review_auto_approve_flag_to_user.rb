class AddInkReviewAutoApproveFlagToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :auto_approve_ink_reviews, :boolean, default: false
  end
end
