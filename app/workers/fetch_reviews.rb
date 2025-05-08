class FetchReviews
  include Sidekiq::Worker

  def perform
    feeds.each { |url| FetchReviews::GenericRss.perform_async(url) }
    youtube_channels.each { |channel_id| FetchReviews::YoutubeChannel.perform_async(channel_id) }
  end

  private

  def feeds
    %w[
      https://www.fountainpenpharmacist.com/feeds/posts/default?alt=rss
      https://wondernaut.wordpress.com/category/ink-review/feed/
      https://www.wellappointeddesk.com/category/ink-review/feed/
      https://macchiatoman.com/?format=rss
      https://www.inkyinspirations.com/inkreviews?format=rss
      https://mountainofink.com/?format=rss
      https://penaddict.com/blog?format=rss
    ]
  end

  def youtube_channels
    ::YouTubeChannel.channel_ids_for_reviews
  end
end
