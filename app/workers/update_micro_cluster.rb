class UpdateMicroCluster
  include Sidekiq::Worker

  def perform(id)
    cluster = MicroCluster.find(id)
    UpdateMacroCluster.perform_async(cluster.macro_cluster_id) if cluster.macro_cluster_id
  end
end
