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
      { state: "no_feed", discovered_at: nil, **streak_reset }
    elsif review_feed.state == "active"
      {}
    elsif review_feed.failing?
      { state: "active", **streak_reset }
    else
      { state: "active", back_catalog_imported: false, **streak_reset }
    end
  end

  def streak_reset
    { **ReviewFeed::FAILURE_RESET, empty_since: nil }
  end
end
