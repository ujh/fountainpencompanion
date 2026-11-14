class FeedParser
  class Error < StandardError
  end

  ABSOLUTE_URL = /\A[a-z][a-z0-9+.-]*:/i

  def initialize(body, feed_url)
    self.body = body
    self.feed_url = feed_url
  end

  def perform
    Feedjira.parse(body).entries.filter_map { |entry| item_for(entry) }
  rescue Feedjira::NoParserAvailable, JSON::ParserError => e
    raise Error, e.message
  end

  private

  attr_accessor :body, :feed_url

  def item_for(entry)
    url = absolute_url(entry.try(:alternate_url).presence || entry.url)
    return unless url

    { url:, title: clean(entry.title), categories: categories_for(entry) }
  end

  def absolute_url(raw_url)
    url = raw_url.to_s.strip
    return if url.blank?

    url = URI.join(feed_url, url).to_s unless url.match?(ABSOLUTE_URL)
    url if url.match?(%r{\Ahttps?://}i)
  rescue URI::Error
    nil
  end

  def categories_for(entry)
    Array(entry.try(:categories)).map { |category| clean(category) }.compact_blank.uniq
  end

  def clean(text)
    text.to_s.delete("\u0000").strip
  end
end
