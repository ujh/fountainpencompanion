class CheckBrandClusters
  include Sidekiq::Worker

  def perform
    MacroCluster.find_each do |macro_cluster|
      CheckBrandCluster.perform_async(macro_cluster.id)
    end
  end
end
