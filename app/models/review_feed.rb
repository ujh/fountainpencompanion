class ReviewFeed < ApplicationRecord
  STATES = %w[active no_feed ignored failing duplicate].freeze
  FETCHABLE_STATES = %w[active failing].freeze
  FAILING_AFTER = 3.days
  EMPTY_AFTER = 7.days
  FAILURE_RESET = { failure_count: 0, first_failed_at: nil, last_error: nil }.freeze
  HOST_FORMAT = /\A[a-z0-9_-]+(\.[a-z0-9_-]+)*\z/
  SCHEME_PREFIX = %r{\A[a-z][a-z0-9+.-]*://}i
  AUTHORITY = %r{\A[a-z][a-z0-9+.-]*://[^/?#]+}i
  DENYLIST = %w[
    youtube.com
    youtu.be
    instagram.com
    reddit.com
    wikipedia.org
    fountainpennetwork.com
    facebook.com
    medium.com
    pinterest.com
    flickr.com
    fountainpennetwork.net
    badgerandblade.com
    ko-fi.com
    write.as
  ].freeze
  QUALIFYING_REVIEW_COUNT = 3
  QUALIFYING_RECENCY = 2.years
  REDISCOVER_AFTER = 30.days

  has_many :web_page_for_reviews, dependent: :nullify

  normalizes :feed_url, with: ->(url) { url.strip.presence }

  before_validation :normalize_host_attribute

  validates :state, inclusion: { in: STATES }
  validates :host, presence: true, uniqueness: true
  validates :host, format: { with: HOST_FORMAT }, allow_blank: true
  validates :feed_url, uniqueness: { allow_nil: true }
  validates :feed_url, presence: true, if: :fetchable_state?
  validate :feed_url_is_http_url

  scope :fetchable, -> { where(state: FETCHABLE_STATES).where.not(feed_url: nil) }
  scope :stale_empty, -> { where(empty_since: ...EMPTY_AFTER.ago) }
  scope :due_for_rediscovery,
        -> do
          where(state: "no_feed").where(
            "discovered_at IS NULL OR discovered_at < ?",
            REDISCOVER_AFTER.ago
          )
        end

  def self.normalize_host(host_or_url)
    value = host_or_url.to_s.strip
    value = "http://#{value}" unless value.match?(SCHEME_PREFIX)
    authority = value[AUTHORITY]
    return if authority.blank?

    host = URI.parse(authority).host.to_s.downcase.delete_prefix("www.")
    host if host.match?(HOST_FORMAT)
  rescue URI::InvalidURIError
    nil
  end

  def self.denylisted?(host_or_url)
    host = normalize_host(host_or_url)
    return false if host.nil?

    DENYLIST.any? { |denied| host == denied || host.end_with?(".#{denied}") }
  end

  def self.qualifying_hosts
    InkReview
      .approved
      .where(you_tube_channel_id: nil)
      .where.not(host: nil)
      .where(
        "NOT EXISTS (SELECT 1 FROM review_feeds WHERE review_feeds.host = #{InkReview::NORMALIZED_HOST})"
      )
      .group(InkReview::NORMALIZED_HOST)
      .having("count(*) >= ?", QUALIFYING_REVIEW_COUNT)
      .having("max(ink_reviews.created_at) > ?", QUALIFYING_RECENCY.ago)
      .order(InkReview::NORMALIZED_HOST)
      .pluck(InkReview::NORMALIZED_HOST)
      .select { |host| normalize_host(host) == host }
      .reject { |host| denylisted?(host) }
  end

  def due_for_rediscovery?
    state == "no_feed" && (discovered_at.nil? || discovered_at < REDISCOVER_AFTER.ago)
  end

  def fetchable_state?
    FETCHABLE_STATES.include?(state)
  end

  def failing?
    state == "failing"
  end

  def stale_empty?(at = Time.current)
    empty_since.present? && empty_since < at - EMPTY_AFTER
  end

  def due?(hour)
    if curated
      true
    elsif failing?
      id % 24 == hour
    else
      id % 4 == hour % 4
    end
  end

  private

  def normalize_host_attribute
    self.host = self.class.normalize_host(host) || host
  end

  def feed_url_is_http_url
    return if feed_url.nil? || SafeHttp.parse_uri(feed_url)

    errors.add(:feed_url, "must be an http(s) URL with a host")
  end
end
