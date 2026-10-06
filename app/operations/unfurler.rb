class Unfurler
  Result =
    Struct.new(
      :url,
      :title,
      :description,
      :image,
      :author,
      :you_tube_channel_id,
      :is_youtube_short,
      :raw_html,
      :youtube
    )

  def initialize(url, with_full_metadata: false)
    self.uri = URI(url)
    self.with_full_metadata = with_full_metadata
  end

  def perform
    result = unfurler.perform
    result.url ||= final_url
    enrich_youtube_metadata(result) if with_full_metadata && result.you_tube_channel_id.present?
    result
  end

  private

  attr_accessor :uri, :with_full_metadata, :response

  def unfurler
    youtube? ? Unfurler::Youtube.new(video_id) : Unfurler::Html.new(html)
  end

  def enrich_youtube_metadata(result)
    yt = result.youtube || { tags: [], comments: nil, captions: nil }
    yt[:comments] ||= Unfurler::Youtube::Comments.new(video_id).fetch
    yt[:captions] ||= Unfurler::Youtube::Captions.new(video_id).fetch
    result.youtube = yt
  end

  def youtube?
    video_id.present?
  end

  def video_id
    @video_id ||= ::Youtube::VideoIdParser.parse(uri.to_s)
  end

  # The URL the page was actually served from (after redirects), falling
  # back to the submitted URL when nothing was fetched (YouTube path).
  def final_url
    response&.final_url.presence || uri.to_s
  end

  def html
    self.response = SafeHttp.get(uri.to_s)
    response.body
  end
end
