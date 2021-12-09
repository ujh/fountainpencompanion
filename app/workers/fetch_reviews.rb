class FetchReviews
  include Sidekiq::Worker

  def perform
    FetchReviews::MountainOfInk.perform_async
  end
end
