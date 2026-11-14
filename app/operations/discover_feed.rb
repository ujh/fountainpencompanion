class DiscoverFeed
  FEED_TYPES = %w[application/rss+xml application/atom+xml].freeze
  FALLBACK_PATHS = %w[
    /feed/
    /?format=rss
    /feeds/posts/default?alt=rss
    /rss/
    /atom.xml
    /feed.xml
    /index.xml
  ].freeze
  COMMENT_FEED_URL = %r{/comments\b|comments-(rss|atom)}i
  MAX_SAMPLE_URLS = 3
  MAX_FETCHES = 12

  def initialize(host:, sample_urls: [])
    self.host = host
    self.sample_urls = Array(sample_urls).compact_blank.first(MAX_SAMPLE_URLS)
    self.homepage_url = site_root(self.sample_urls.first) || "https://#{host}/"
    self.responses = {}
  end

  def perform
    pages = page_urls.index_with { |url| fetch(url) }.compact
    hosts = site_hosts(pages.values)
    candidates = (linked_feeds(pages) + fallback_urls).uniq
    candidates.lazy.filter_map { |url| site_feed_url(url, hosts) }.first
  end

  private

  attr_accessor :host, :sample_urls, :homepage_url, :responses

  def page_urls
    (sample_urls + [homepage_url]).uniq
  end

  def fallback_urls
    FALLBACK_PATHS.map { |path| URI.join(homepage_url, path).to_s }
  end

  def site_root(url)
    uri = SafeHttp.parse_uri(url)
    URI.join(uri, "/").to_s if uri
  end

  def site_hosts(pages)
    [host, *pages.map(&:final_url)].filter_map { |url| ReviewFeed.normalize_host(url) }.to_set
  end

  def fetch(url)
    return responses[url] if responses.key?(url)
    return if responses.size >= MAX_FETCHES

    responses[url] = get(url)
  end

  def get(url)
    SafeHttp.get(url)
  rescue Faraday::Error, URI::Error
    nil
  end

  def linked_feeds(pages)
    pages.flat_map do |url, page|
      links = feed_links(page)
      url == homepage_url ? links : links.reject { |link| under_page?(link, page) }
    end
  end

  def feed_links(page)
    Nokogiri
      .HTML(page.body)
      .css("link[rel][href]")
      .filter_map do |link|
        next unless feed_link?(link)

        url = absolute_url(link["href"], page.final_url)
        url unless url.nil? || comment_feed?(url, link["title"])
      end
  end

  def feed_link?(link)
    rels = link["rel"].downcase.split
    type = link["type"].to_s.split(";").first.to_s.strip.downcase
    rels.include?("alternate") && FEED_TYPES.include?(type)
  end

  def absolute_url(href, base_url)
    url = URI.join(base_url, href.strip).to_s
    url if SafeHttp.parse_uri(url)
  rescue URI::Error
    nil
  end

  def comment_feed?(url, title)
    url.match?(COMMENT_FEED_URL) || title.to_s.match?(/comments/i)
  end

  def under_page?(url, page)
    path = URI(page.final_url).path.chomp("/")
    path.present? && url.start_with?(URI.join(page.final_url, "#{path}/").to_s)
  rescue URI::Error
    false
  end

  def site_feed_url(url, hosts)
    response = fetch(url)
    return unless response

    items = FeedParser.new(response.body, response.final_url).perform
    response.final_url if mostly_on_site?(items, hosts)
  rescue FeedParser::Error
    nil
  end

  def mostly_on_site?(items, hosts)
    on_site = items.count { |item| hosts.include?(ReviewFeed.normalize_host(item[:url])) }
    on_site * 2 > items.size
  end
end
