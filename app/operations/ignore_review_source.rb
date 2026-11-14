class IgnoreReviewSource
  def initialize(ink_review)
    self.ink_review = ink_review
  end

  def perform
    source = self.source
    case source
    when YouTubeChannel
      source.update!(ignored: true)
    when ReviewFeed
      ignore_feed(source)
    else
      false
    end
  end

  def source
    ink_review.you_tube_channel || page_feed || host_feed
  end

  def curated_feed
    source = self.source
    return unless source.is_a?(ReviewFeed) && source.curated

    source if source.fetchable_state?
  end

  private

  attr_accessor :ink_review

  def page_feed
    ReviewFeed
      .joins(:web_page_for_reviews)
      .where(web_page_for_reviews: { url: review_urls })
      .order("web_page_for_reviews.id DESC")
      .first
  end

  def review_urls
    [ink_review.url, *ink_review.ink_review_submissions.pluck(:url)].uniq
  end

  def host_feed
    host = ReviewFeed.normalize_host(ink_review.host)
    return if host.nil? || ReviewFeed.denylisted?(host)

    ReviewFeed.find_by(host:) || ReviewFeed.new(host:)
  end

  def ignore_feed(feed)
    if feed.persisted?
      feed.update!(state: "ignored")
    else
      ReviewFeed.upsert({ host: feed.host, state: "ignored" }, unique_by: :host)
      true
    end
  end
end
