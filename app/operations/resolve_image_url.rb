require "faraday/follow_redirects"

class ResolveImageUrl
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 5
  MAX_REDIRECTS = 5

  def initialize(url)
    self.url = url
  end

  def perform
    return nil if url.blank?

    response = connection.head(url)
    return nil unless response.success?
    return nil unless response.headers["content-type"].to_s.start_with?("image/")

    response.env.url.to_s
  rescue Faraday::Error, URI::InvalidURIError, ArgumentError
    nil
  end

  private

  attr_accessor :url

  def connection
    Faraday.new do |f|
      f.response :follow_redirects, limit: MAX_REDIRECTS
      f.options.open_timeout = OPEN_TIMEOUT
      f.options.timeout = READ_TIMEOUT
    end
  end
end
