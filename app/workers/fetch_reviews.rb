class FetchReviews
  include Sidekiq::Worker

  def perform
    feeds.each { |url| FetchReviews::GenericRss.perform_async(url) }
    youtube_channels.each { |channel_id| FetchReviews::YoutubeChannel.perform_async(channel_id) }
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
