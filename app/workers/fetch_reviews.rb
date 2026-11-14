class FetchReviews
  include Sidekiq::Worker

  STAGGER_INTERVAL = 30 # seconds between enqueued source jobs
  SPREAD_WINDOW = 3600 # seconds the source jobs of one run are spread over

  def perform
    jobs = due_feeds.map { |feed| [FetchReviews::GenericRss, feed.id] }
    jobs += youtube_channels.map { |channel_id| [FetchReviews::YoutubeChannel, channel_id] }

    # Spread the per-source jobs out instead of enqueueing them all at once. Each
    # source can fan out into embedding-heavy ProcessWebPageForReview work, so
    # bunching them at the top of the hour is what spikes the DB.
    interval = stagger_interval(jobs.size)
    jobs.each_with_index { |(worker, arg), i| worker.perform_in(i * interval, arg) }
  end

  private

  def stagger_interval(job_count)
    [STAGGER_INTERVAL, SPREAD_WINDOW.fdiv(job_count)].min
  end

  def due_feeds
    hour = Time.current.utc.hour
    ReviewFeed.fetchable.order(:id).select { |feed| feed.due?(hour) }
  end

  def youtube_channels
    ::YouTubeChannel.channel_ids_for_reviews
  end
end
