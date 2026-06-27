class FetchReviews
  include Sidekiq::Worker

  STAGGER_INTERVAL = 30 # seconds between enqueued source jobs

  def perform
    jobs = feeds.map { |url| [FetchReviews::GenericRss, url] }
    jobs += youtube_channels.map { |channel_id| [FetchReviews::YoutubeChannel, channel_id] }

    # Spread the per-source jobs out instead of enqueueing them all at once. Each
    # source can fan out into embedding-heavy ProcessWebPageForReview work, so
    # bunching them at the top of the hour is what spikes the DB.
    jobs.each_with_index do |(worker, arg), i|
      worker.perform_in((i * STAGGER_INTERVAL).seconds, arg)
    end
  end

  private

  def feeds
    %w[
      https://inkcrediblecolours.com/feed/
      https://inksharks.blogspot.com/feeds/posts/default?alt=rss
      https://inkyfountainpens.wordpress.com/feed/
      https://mountainofink.com/?format=rss
      https://mymanymuses.com/category/ink/feed/
      https://nickstewart.ink/feed
      https://penaddict.com/blog?format=rss
      https://toomanypurples.blogspot.com/feeds/posts/default?alt=rss
      https://wondernaut.wordpress.com/category/ink-review/feed/
      https://writingatlarge.com/feed/
      https://www.fountainpenpharmacist.com/feeds/posts/default?alt=rss
      https://www.inkyinspirations.com/inkreviews?format=rss
      https://www.wellappointeddesk.com/category/ink-review/feed/
    ]
  end

  def youtube_channels
    ::YouTubeChannel.channel_ids_for_reviews
  end
end
