class ReviewFeed < ApplicationRecord
  STATES = %w[active no_feed ignored failing duplicate].freeze
  FETCHABLE_STATES = %w[active failing].freeze
  HOST_FORMAT = /\A[a-z0-9_-]+(\.[a-z0-9_-]+)*\z/

  has_many :web_page_for_reviews, dependent: :nullify

  before_validation :normalize_host_attribute, :normalize_feed_url

  validates :state, inclusion: { in: STATES }
  validates :host, presence: true, uniqueness: true
  validates :feed_url, uniqueness: { allow_nil: true }
  validates :feed_url, presence: true, if: :fetchable_state?

  scope :fetchable, -> { where(state: FETCHABLE_STATES).where.not(feed_url: nil) }

  def self.normalize_host(host_or_url)
    value = host_or_url.to_s.strip
    return if value.blank?

    value = "http://#{value}" unless value.match?(%r{\A[a-z][a-z0-9+.-]*://}i)
    host = URI.parse(value).host.to_s.downcase.delete_prefix("www.")
    host if host.match?(HOST_FORMAT)
  rescue URI::InvalidURIError
    nil
  end

  private

  def normalize_host_attribute
    self.host = self.class.normalize_host(host)
  end

  def normalize_feed_url
    self.feed_url = feed_url.to_s.strip.presence
  end

  def fetchable_state?
    FETCHABLE_STATES.include?(state)
  end
end
