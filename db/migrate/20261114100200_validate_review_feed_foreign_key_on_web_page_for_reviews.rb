class ValidateReviewFeedForeignKeyOnWebPageForReviews < ActiveRecord::Migration[8.1]
  def up
    validate_foreign_key :web_page_for_reviews, :review_feeds
  end

  def down
  end
end
