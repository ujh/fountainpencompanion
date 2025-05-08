class FetchReviews
  class ProcessWebPageForReview
    include Sidekiq::Worker
    sidekiq_options queue: "reviews"

    def peform(page_id)
      self.web_page_for_review = WebPageForReview.find(page_id)
      return unless macro_cluster

      FetchReviews::SubmitReview.perform_async(url, macro_cluster.id)
      web_page_for_review.update!(state: "processed")
    end

    private

    attr_accessor :web_page_for_review

    delegate :url, to: :web_page_for_review

    def macro_cluster
      @macro_cluster ||= MacroCluster.full_text_search(search_term, fuzzy: true).first
    end

    def search_term
      web_page_for_review.data["search_term"]
    end
  end
end
