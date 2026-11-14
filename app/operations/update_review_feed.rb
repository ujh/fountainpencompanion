class UpdateReviewFeed
  REACTIVATED_STATES = %w[no_feed ignored duplicate].freeze

  def initialize(review_feed, review_feed_params)
    self.review_feed = review_feed
    self.review_feed_params = review_feed_params
  end

  def perform
    review_feed.assign_attributes(review_feed_params)
    apply_feed_url_change if review_feed.feed_url_changed?
    review_feed.save
  end

  private

  attr_accessor :review_feed, :review_feed_params

  def apply_feed_url_change
    review_feed.back_catalog_imported = false
    return unless review_feed.feed_url.present? && REACTIVATED_STATES.include?(review_feed.state)

    review_feed.assign_attributes(state: "active", **ReviewFeed::FAILURE_RESET)
  end
end
