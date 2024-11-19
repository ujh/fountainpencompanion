class FetchReviews
  include Sidekiq::Worker

  def perform
    FetchReviews::MountainOfInk.perform_async
    FetchReviews::PenAddict.perform_in(1.minute)
    feeds.each_with_index do |url, i|
      FetchReviews::GenericRss.perform_in(i.minutes, url)
    end
    youtube_channels.each_with_index do |channel_id, i|
      FetchReviews::YoutubeChannel.perform_in(i.minutes, channel_id)
    end
  end

  private

  def feeds
    # Currently down:
    # https://fountainpenpharmacist.com/?format=rss
    %w[
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
