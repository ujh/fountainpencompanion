class AddReviewFeedToWebPageForReviews < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :web_page_for_reviews, :review_feed_id, :bigint, if_not_exists: true

    if index_exists?(:web_page_for_reviews, :review_feed_id, valid: false)
      remove_index :web_page_for_reviews, :review_feed_id, algorithm: :concurrently
    end
    add_index :web_page_for_reviews, :review_feed_id, algorithm: :concurrently, if_not_exists: true

    add_foreign_key :web_page_for_reviews, :review_feeds, validate: false, if_not_exists: true
  end

  def down
    remove_reference :web_page_for_reviews, :review_feed, index: true, foreign_key: true
  end
end
