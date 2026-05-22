class Unfurler
  class Youtube
    def initialize(video_id)
      self.video_id = video_id
    end

    def perform
      result =
        Result.new(url, title, description, image, author, channel_id, is_short, nil, youtube_data)
      result
    end

    private

    attr_accessor :video_id

    def url
      "https://www.youtube.com/watch?#{{ v: video_id }.to_query}"
    end

    def channel_id
      video.snippet.channel_id
    end

    def title
      video.snippet.title
    end

    def description
      video.snippet.description
    end

    def image
      thumbnails = video.snippet.thumbnails
      t = %i[maxres standard medium high default].find { |t| thumbnails.send(t) }
      thumbnails.send(t).url
    end

    def author
      video.snippet.channel_title
    end

    def is_short
      Faraday.get("https://www.youtube.com/shorts/#{video_id}").status == 200
    end

    # Eager: tags ship with the snippet call we already make. Comments and
    # captions are fetched lazily by the caller when needed.
    def youtube_data
      { tags: Array(video.snippet.tags), comments: nil, captions: nil }
    end

    def video
      @video ||= client.list_videos("snippet", id: video_id).items.first
      raise Google::Apis::ClientError, "YouTube video not found: #{video_id}" unless @video
      @video
    end

    def client
      ::Youtube::Client.new
    end
  end
end
