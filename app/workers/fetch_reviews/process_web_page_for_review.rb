class FetchReviews
  class ProcessWebPageForReview
    include Sidekiq::Worker
    include Sidekiq::Throttled::Worker

    sidekiq_throttle concurrency: { limit: 1 }
    sidekiq_options queue: "reviews"

    def perform(page_id)
      web_page_for_review = WebPageForReview.find(page_id)
      ReviewFinder.new(web_page_for_review).perform
      web_page_for_review.update!(state: "processed")
    end
  end
end
