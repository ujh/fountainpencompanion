class FetchReviews
  class SubmitReview
    include Sidekiq::Worker
    include Sidekiq::Throttled::Worker

    sidekiq_throttle concurrency: { limit: 1 }
    sidekiq_options queue: "reviews"

    def perform(url, macro_cluster_id, explanation = nil)
      macro_cluster = MacroCluster.find_by(id: macro_cluster_id)
      submit_review(url, macro_cluster, explanation)
    end

    private

    def submit_review(url, macro_cluster, explanation)
      CreateInkReviewSubmission.new(
        url: url,
        user: user,
        macro_cluster: macro_cluster,
        automatic: true,
        explanation: explanation
      ).perform
    end

    def user
      @user ||= User.find_by(email: "urban@bettong.net")
    end
  end
end
