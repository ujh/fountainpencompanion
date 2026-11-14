class DiscoverReviewFeed
  include Sidekiq::Worker
  include Sidekiq::Throttled::Worker

  sidekiq_throttle concurrency: { limit: 1 }
  sidekiq_options queue: "reviews", retry: 3

  def perform(host)
    DiscoverReviewFeedForHost.new(host).perform
  end
end
