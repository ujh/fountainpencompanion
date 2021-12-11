class FetchReviews
  class YoutubeChannel
    include Sidekiq::Worker

    attr_accessor :channel_id

    def perform(channel_id)
      self.channel_id = channel_id
      import!
    end

    private

    def import!
      client.fetch_videos.take(5).each do |video|
        video = video.merge(search_term: video[:title])
        video = match(video)
        submit(video)
      end
    end

    def submit(video)
      FetchReviews::SubmitReview.perform_async(
        video[:url],
        video[:macro_cluster]
      )
    end

    def match(video)
      cluster = MacroCluster.full_text_search(video[:search_term]).first
      video.merge(macro_cluster: cluster&.id)
    end

    def client
      @client ||= Youtube.new(channel_id: channel_id)
    end
  end
end
