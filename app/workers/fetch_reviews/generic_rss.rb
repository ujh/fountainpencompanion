class FetchReviews
  class GenericRss
    include Sidekiq::Worker
    include FetchReviews::ViaRss

    attr_accessor :feed_url

    def perform(url)
      self.feed_url = url
      super()
    end
  end
end
