class FetchReviews
  class RecalculateAll
    include Sidekiq::Worker
    sidekiq_options queue: "reviews"

    def perform
      InkReview.find_each do |ink_review|
        FetchReviews::RecalculateOne.perform_at(
          rand(60 * 5).seconds.from_now,
          ink_review.id
        )
      end
    end
  end
end
