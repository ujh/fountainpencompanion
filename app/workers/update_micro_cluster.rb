class UpdateMicroCluster
  include Sidekiq::Worker

  def perform(id)
    cluster = MicroCluster.find(id)
    if cluster.macro_cluster_id
      UpdateMacroCluster.perform_async(cluster.macro_cluster_id)
    else
      RunAgent.perform_async("InkClusterer", cluster.id)
    end
  end
end
