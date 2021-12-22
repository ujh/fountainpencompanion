class Unfurler
  class Youtube
    def initialize(video_id)
      self.video_id = video_id
    end

    def perform
      Result.new(nil, title, description, image, author)
    end

    private

    attr_accessor :video_id

    def title
      video.snippet.title
    end

    def description
      video.snippet.description
    end

    def image
      video.snippet.thumbnails.default.url
    end

    def author
      video.snippet.channel_title
    end

    def video
      @video ||= client.list_videos('snippet', id: video_id).items.first
    end

    def client
      ::Youtube::Client.new
    end
  end
end
