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
        video = match(video)
        submit(video)
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

    def submit(video)
      FetchReviews::SubmitReview.perform_async(
        video[:url],
        video[:macro_cluster]
      )
    end

    def match(video)
      Rails
        .cache
        .fetch("youtube:#{video[:url]}", expires_in: 1.year) do
          cluster = MacroCluster.full_text_search(video[:search_term]).first
          video.merge(macro_cluster: cluster&.id)
        end
    end

    def client
      @client ||= Youtube.new(channel_id: channel_id)
    end
  end
end
