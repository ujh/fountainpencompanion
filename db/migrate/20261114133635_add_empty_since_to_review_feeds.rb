class AddEmptySinceToReviewFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :review_feeds, :empty_since, :datetime
  end
end
