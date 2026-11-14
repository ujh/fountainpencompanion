class AddReviewFeedToWebPageForReviews < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_reference :web_page_for_reviews,
                  :review_feed,
                  index: {
                    algorithm: :concurrently
                  },
                  foreign_key: {
                    validate: false
                  }
  end

  def down
    remove_reference :web_page_for_reviews, :review_feed, index: true, foreign_key: true
  end
end
