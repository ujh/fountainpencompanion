class FetchReviews
  class MountainOfInk
    include Sidekiq::Worker
    include FetchReviews::ViaRss
    sidekiq_options queue: "reviews"

    def feed_url
      "https://mountainofink.com/?format=rss"
    end

    def process_review(review)
      review.merge(search_term: review[:title].split(":").last.strip)
    end
  end
end
