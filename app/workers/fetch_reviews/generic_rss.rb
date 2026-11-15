class FetchReviews
  class GenericRss
    include Sidekiq::Worker
    include Sidekiq::Throttled::Worker

    sidekiq_throttle concurrency: { limit: 1 }
    sidekiq_options queue: "reviews"

    def perform(review_feed_id)
      review_feed = ReviewFeed.fetchable.find_by(id: review_feed_id)
      FetchReviewFeed.new(review_feed).perform if review_feed
    end
  end
end
