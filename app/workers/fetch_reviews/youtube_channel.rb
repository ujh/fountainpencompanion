class FetchReviews
  class YoutubeChannel
    include Sidekiq::Worker
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
        video = video.merge(search_term: video[:title])
        next if WebPageForReview.where(url: video[:url]).exists?

        page =
          WebPageForReview.create!(url: video[:url], data: { search_term: video[:search_term] })
        if Rails.cache.exist?("youtube:#{video[:url]}")
          page.update!(state: "processed")
        else
          FetchReviews::ProcessWebPageForReview.perform_async(page.id)
        end
      end
    end

    def videos
      if channel.back_catalog_imported
        client.fetch_videos.take(5)
      else
        channel.update!(back_catalog_imported: true)
        client.fetch_videos
      end
    end

    def client
      @client ||= Youtube.new(channel_id: channel_id)
    end
  end
end
