class ChangeReviewFeedState
  def initialize(review_feed, enabled:)
    self.review_feed = review_feed
    self.enabled = enabled
  end

  def perform
    review_feed.update(enabled ? enabled_attributes : { state: "ignored" })
  end

  private

  attr_accessor :review_feed, :enabled

  def enabled_attributes
    if review_feed.feed_url.blank?
      { state: "no_feed", discovered_at: nil, **ReviewFeed::FAILURE_RESET }
    elsif review_feed.state == "active"
      {}
    elsif review_feed.failing?
      { state: "active", **ReviewFeed::FAILURE_RESET }
    else
      { state: "active", back_catalog_imported: false, **ReviewFeed::FAILURE_RESET }
    end
  end
end
