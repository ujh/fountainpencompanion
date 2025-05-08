class FetchReviews
  class ProcessWebPageForReview
    include Sidekiq::Worker
    sidekiq_options queue: "reviews"

    def perform(page_id)
      web_page_for_review = WebPageForReview.find(page_id)
      ReviewFinder.new(web_page_for_review).perform
      web_page_for_review.update!(state: "processed")
    end
  end
end
