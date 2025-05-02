class Unfurler
  class Youtube
    def initialize(video_id)
      self.video_id = video_id
    end

    def perform
      Result.new(url, title, description, image, author, channel_id, is_short)
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

    def video
      @video ||= client.list_videos("snippet", id: video_id).items.first
    end

    def client
      ::Youtube::Client.new
    end
  end
end
