class CheckNewClusters
  include Sidekiq::Worker

  def perform
    # Raw returns a string, but we need a number for the decrement below to work
    # and not do an increment instead.
    new_clusters = Rails.cache.read("new_cluster_count", raw: true).to_i
    return unless new_clusters.positive?

    AdminMailer.new_cluster(new_clusters).deliver_later
    Rails.cache.decrement("new_cluster_count", new_clusters)
  end
end
