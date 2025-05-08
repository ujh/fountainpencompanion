class FetchReviews
  class RecalculateOne
    include Sidekiq::Worker
    include Sidekiq::Throttled::Worker

    sidekiq_throttle concurrency: { limit: 1 }
    sidekiq_options queue: "reviews"

    def perform(ink_review_id)
      self.ink_review = InkReview.find(ink_review_id)
      ink_review.update!(title: title, description: description, image: image, author: author)
    end

    private

    attr_accessor :ink_review

    delegate :title, :description, :image, :author, to: :page_data

    def page_data
      @page_data ||= Unfurler.new(ink_review.url).perform
    end
  end
end
