class FetchReviews
  class PenAddict
    include Sidekiq::Worker
    include FetchReviews::ViaRss
    sidekiq_options queue: "reviews"

    def feed_url
      "https://penaddict.com/blog?format=rss"
    end

    def process_review(review)
      return if review[:title] =~ /giveaway/i

      review
    end
  end
end
