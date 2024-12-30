class CheckNewClusters
  include Sidekiq::Worker

  def perform
    new_clusters = Rails.cache.read("new_cluster_count", raw: true)
    return unless new_clusters.to_i.positive?

    AdminMailer.new_cluster(new_clusters).deliver_later
    Rails.cache.decrement("new_cluster_count", new_clusters)
  end
end
