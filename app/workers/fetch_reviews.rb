class FetchReviews
  include Sidekiq::Worker

  def perform
    FetchReviews::MountainOfInk.perform_async
    FetchReviews::PenAddict.perform_async
    feeds.each do |url|
      FetchReviews::GenericRss.perform_async(url)
    end
    youtube_channels.each do |channel_id|
      FetchReviews::YoutubeChannel.perform_async(channel_id)
    end
  end

  private

  def feeds
    [
      'https://fountainpenpharmacist.com/?format=rss',
      'https://wondernaut.wordpress.com/category/ink-review/feed/',
      'https://www.wellappointeddesk.com/category/ink-review/feed/',
      'https://macchiatoman.com/?format=rss',
      'http://www.inkdependence.com/feeds/posts/default?alt=rss',
    ]
  end

  def youtube_channels
    [
      'UCruW1x5gCc21b0khnEzrOgg', # Mick L
      'UCZaWG7RkmQVLE0EmvfOuJ9w', # Inky Rocks
      'UCNCL45NnxiFKOoXB8sy6OYA', # The Inked Well
      'UClEwjXhW8IekvkQlg2KZzAw', # Mike Matteson
      'UCMyv8yHpaI6_KGHvq0TttOw', # An Ink Guy
      'UCbIT8Rc2HNrdC2VMjqyKWdg', # Chris Saenz
      'UCx_N2ZoaMXpxWkCRYAKWObw', # What I Ink
    ]
  end
end