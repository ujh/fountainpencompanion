class FetchReviews
  include Sidekiq::Worker

  def perform
    FetchReviews::MountainOfInk.perform_async
    FetchReviews::PenAddict.perform_async
    feeds.each do |url|
      FetchReviews::GenericRss.perform_async(url)
    end
  end

  private

  def feeds
    [
      'https://fountainpenpharmacist.com/?format=rss'
    ]
  end
end
