class FetchReviews
  include Sidekiq::Worker

  def perform
    FetchReviews::MountainOfInk.perform_async
    FetchReviews::PenAddict.perform_async
    feeds.each { |url| FetchReviews::GenericRss.perform_async(url) }
    youtube_channels.each do |channel_id|
      FetchReviews::YoutubeChannel.perform_async(channel_id)
    end
  end

  private

  def feeds
    %w[
      https://fountainpenpharmacist.com/?format=rss
      https://wondernaut.wordpress.com/category/ink-review/feed/
      https://www.wellappointeddesk.com/category/ink-review/feed/
      https://macchiatoman.com/?format=rss
      https://www.inkyinspirations.com/inkreviews?format=rss
    ]
  end

  def youtube_channels
    ::YouTubeChannel.channel_ids_for_reviews
  end
end
