class DiscoverReviewFeeds
  include Sidekiq::Worker

  sidekiq_options queue: "reviews"

  STAGGER_INTERVAL = 60

  def perform
    hosts.each_with_index do |host, i|
      DiscoverReviewFeed.perform_in((i * STAGGER_INTERVAL).seconds, host)
    end
  end

  private

  def hosts
    ReviewFeed.qualifying_hosts + ReviewFeed.due_for_rediscovery.order(:host).pluck(:host)
  end
end
