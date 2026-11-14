class FetchReviews
  class GenericRss
    include Sidekiq::Worker
    include Sidekiq::Throttled::Worker

    sidekiq_throttle concurrency: { limit: 1 }
    sidekiq_options queue: "reviews"

    def perform(feed_id_or_url)
      review_feed = find_review_feed(feed_id_or_url)
      FetchReviewFeed.new(review_feed).perform if review_feed
    end

    private

    def find_review_feed(feed_id_or_url)
      feeds = ReviewFeed.fetchable
      if feed_id_or_url.is_a?(String)
        feeds.find_by(feed_url: feed_id_or_url)
      else
        feeds.find_by(id: feed_id_or_url)
      end
    end
  end
end
