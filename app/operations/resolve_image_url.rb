class ResolveImageUrl
  def initialize(url)
    self.url = url
  end

  def perform
    return nil if url.blank?

    response = SafeHttp.head(url)
    return nil unless (200..299).cover?(response.status)
    return nil unless response.headers["content-type"].to_s.start_with?("image/")

    response.env.url.to_s
  rescue Faraday::Error, URI::InvalidURIError, ArgumentError
    nil
  end

  private

  attr_accessor :url
end
