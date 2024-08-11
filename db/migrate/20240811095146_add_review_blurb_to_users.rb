class AddReviewBlurbToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :review_blurb, :boolean, default: false
  end
end
