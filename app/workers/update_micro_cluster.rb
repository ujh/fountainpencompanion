class UpdateMicroCluster
  include Sidekiq::Worker

  # Simplified brand names that are never enqueued for clustering from this
  # worker, e.g. brands that are really a single user's own ink mixes. The
  # blacklist wins over admin actions: unignoring or unassigning such a micro
  # cluster ignores it again rather than sending it back to the clusterer.
  IGNORED_BRANDS = %w[sirius].freeze

  def perform(id)
    cluster = MicroCluster.find(id)
    return if cluster.ignored?

    if cluster.macro_cluster_id
      UpdateMacroCluster.perform_async(cluster.macro_cluster_id)
    elsif IGNORED_BRANDS.include?(cluster.simplified_brand_name)
      cluster.update!(ignored: true)
    else
      RunInkClustererAgent.perform_in(InkClusterer::DEBOUNCE_WINDOW, "InkClusterer", cluster.id)
    end
  end
end
