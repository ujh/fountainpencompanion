class FetchReviews
  class ProcessWebPageForReview
    include Sidekiq::Worker
    sidekiq_options queue: "reviews"

    def perform(page_id)
      self.web_page_for_review = WebPageForReview.find(page_id)
      return unless macro_cluster

      ReviewFinder.new(web_page_for_review).perform
      web_page_for_review.update!(state: "processed")
    end

    private

    attr_accessor :web_page_for_review
  end
end
