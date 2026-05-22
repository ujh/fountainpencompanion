class Unfurler
  class Youtube
    class Comments
      MAX_RESULTS = 10

      def initialize(video_id, client: ::Youtube::Client.new)
        self.video_id = video_id
        self.client = client
      end

      def fetch
        response =
          client.list_comment_threads(
            "snippet",
            video_id: video_id,
            order: "relevance",
            max_results: MAX_RESULTS
          )
        Array(response.items).map { |item| transform(item) }
      rescue Google::Apis::ClientError => e
        return [] if comments_unavailable?(e)
        raise
      end

      private

      attr_accessor :video_id, :client

      def transform(item)
        top = item.snippet.top_level_comment.snippet
        { author: top.author_display_name, text: top.text_display, like_count: top.like_count }
      end

      def comments_unavailable?(error)
        message = error.message.to_s
        message.include?("commentsDisabled") || message.include?("forbidden") ||
          message.include?("disabled comments")
      end
    end
  end
end
