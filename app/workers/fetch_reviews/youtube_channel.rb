class FetchReviews
  class YoutubeChannel
    include Sidekiq::Worker
    include Sidekiq::Throttled::Worker

    sidekiq_throttle concurrency: { limit: 1 }
    sidekiq_options queue: "reviews"

    def perform(channel_id)
      self.channel = YouTubeChannel.find_by!(channel_id: channel_id)
      import!
    end

    private

    attr_accessor :channel
    delegate :channel_id, to: :channel

    def import!
      videos.each do |video|
        next if WebPageForReview.where(url: video[:url]).exists?

        page = WebPageForReview.create!(url: video[:url], data: { search_term: video[:title] })
        FetchReviews::ProcessWebPageForReview.perform_async(page.id)
      end
    end

    def videos
      client.fetch_videos.take(5)
    end

    def client
      @client ||= Youtube.new(channel_id: channel_id)
    end
  end
end
