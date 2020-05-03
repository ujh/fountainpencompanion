class AssignMacroCluster
  include Sidekiq::Worker

  def perform(macro_cluster_id)
    macro_cluster = MacroCluster.find(macro_cluster_id)
    brand_cluster = BrandCluster.find_by(name: macro_cluster.brand_name)
    macro_cluster.update(brand_cluster: brand_cluster)
  end
end
