class FetchReviews
  module ViaRss
    # As we run this multiple times a day we do not have to process all reviews
    # every time.
    REVIEW_COUNT = 5

    def feed_url
      raise NotImplementedError
    end

    def process_review(review)
      review
    end

    def perform
      reviews =
        feed.items.map { |item| { url: item.link, title: item.title, search_term: item.title } }
      reviews = reviews.map { |review| process_review(review) }
      reviews = reviews.compact
      reviews = reviews.take(REVIEW_COUNT)
      reviews = reviews.map { |review| match_review(review) }
      reviews.map { |review| submit_review(review) }
    end

    private

    def match_review(review)
      Rails
        .cache
        .fetch("rss:#{review[:url]}", expires_in: 1.year) do
          cluster = MacroCluster.full_text_search(review[:search_term], fuzzy: true).first
          review.merge(macro_cluster: cluster&.id)
        end
    end

    def submit_review(review)
      FetchReviews::SubmitReview.perform_async(review[:url], review[:macro_cluster])
    end

    def feed
      connection =
        Faraday.new do |c|
          c.response :follow_redirects
          c.response :raise_error
        end
      RSS::Parser.parse(connection.get(feed_url).body)
    end
  end
end
