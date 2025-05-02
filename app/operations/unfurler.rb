class Unfurler
  Result =
    Struct.new(:url, :title, :description, :image, :author, :you_tube_channel_id, :is_youtube_short)

  def initialize(url)
    self.uri = URI(url)
  end

  def perform
    result = unfurler.perform
    result.url ||= uri.to_s
    result
  end

  private

  attr_accessor :uri

  def unfurler
    youtube? ? Unfurler::Youtube.new(video_id) : Unfurler::Html.new(html)
  end

  def youtube?
    uri.host =~ /youtube.com|youtu.be/ && video_id.present?
  end

  def video_id
    Rack::Utils.parse_query(uri.query)["v"]
  end

  def html
    connection =
      Faraday.new do |c|
        c.response :follow_redirects
        c.response :raise_error
      end
    connection.get(uri).body
  end
end
