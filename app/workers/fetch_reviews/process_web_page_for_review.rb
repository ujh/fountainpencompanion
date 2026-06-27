class FetchReviews
  class ProcessWebPageForReview
    include Sidekiq::Worker
    include Sidekiq::Throttled::Worker

    # ReviewFinder runs the non-performant MacroCluster.embedding_search (three
    # pgvector scans over every ink embedding). Cap concurrency at 1 and rate
    # limit so these heavy scans space out over time rather than running
    # back-to-back when a fetch fans out many pages at once.
    sidekiq_throttle concurrency: { limit: 1 }, threshold: { limit: 1, period: 30 }
    sidekiq_options queue: "reviews"

    def perform(page_id)
      web_page_for_review = WebPageForReview.find(page_id)
      ReviewFinder.new(web_page_for_review).perform
      web_page_for_review.update!(state: "processed")
    end
  end
end
