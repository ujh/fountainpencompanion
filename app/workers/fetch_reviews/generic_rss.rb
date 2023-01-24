class FetchReviews
  class GenericRss
    include Sidekiq::Worker
    include FetchReviews::ViaRss
    sidekiq_options queue: "reviews"

    attr_accessor :feed_url

    def perform(url)
      self.feed_url = url
      super()
    end
  end
end
