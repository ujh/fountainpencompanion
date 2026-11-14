class DiscoverReviewFeedForHost
  SAMPLE_SIZE = 3

  def initialize(host)
    self.host = ReviewFeed.normalize_host(host)
  end

  def perform
    return false if host.nil?
    return false unless discoverable?(ReviewFeed.find_by(host:))

    save(DiscoverFeed.new(host:, sample_urls:).perform)
  end

  private

  attr_accessor :host

  def discoverable?(review_feed)
    review_feed.nil? || review_feed.state == "no_feed"
  end

  def sample_urls
    InkReview
      .approved
      .with_normalized_host(host)
      .order(created_at: :desc, id: :desc)
      .limit(SAMPLE_SIZE)
      .pluck(:url)
  end

  def save(feed_url)
    ReviewFeed.transaction do
      review_feed = ReviewFeed.lock.find_by(host:)
      if discoverable?(review_feed)
        review_feed ||= ReviewFeed.new(host:)
        review_feed.update!(discovery_attributes(feed_url, review_feed))
        true
      else
        false
      end
    end
  rescue ActiveRecord::RecordNotUnique
    false
  end

  def discovery_attributes(feed_url, review_feed)
    attributes =
      if feed_url.nil?
        { state: "no_feed", feed_url: nil, last_error: nil }
      elsif ReviewFeed.denylisted?(feed_url)
        { state: "no_feed", feed_url: nil, last_error: "Feed #{feed_url} is on a denylisted host" }
      elsif (other = feed_owner(feed_url, review_feed))
        {
          state: "duplicate",
          feed_url: nil,
          last_error: "Feed #{feed_url} belongs to #{other.host}"
        }
      else
        active_attributes(feed_url)
      end
    attributes.merge(discovered_at: Time.current)
  end

  def feed_owner(feed_url, review_feed)
    ReviewFeed.where(feed_url:).where.not(id: review_feed.id).first
  end

  def active_attributes(feed_url)
    { state: "active", feed_url:, curated: false, back_catalog_imported: false, last_error: nil }
  end
end
