class FetchReviews
  module ViaRss
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
      reviews.each do |review|
        next if WebPageForReview.where(url: review[:url]).exists?

        page =
          WebPageForReview.create!(url: review[:url], data: { search_term: review[:search_term] })
        if Rails.cache.exist?("rss:#{review[:url]}")
          page.update!(state: "processed")
        else
          FetchReviews::ProcessWebPageForReview.perform_async(page.id)
        end
      end
    end

    private

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
