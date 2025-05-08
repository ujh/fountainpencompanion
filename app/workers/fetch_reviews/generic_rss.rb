class FetchReviews
  class GenericRss
    include Sidekiq::Worker
    include FetchReviews::ViaRss
    include Sidekiq::Throttled::Worker

    sidekiq_throttle concurrency: { limit: 1 }
    sidekiq_options queue: "reviews"

    attr_accessor :feed_url

    def perform(url)
      self.feed_url = url
      super()
    end
  end
end
