class AssignMacroCluster
  include Sidekiq::Worker

  def perform(macro_cluster_id)
    self.macro_cluster = MacroCluster.find(macro_cluster_id)
    if brand_cluster
      macro_cluster.update(brand_cluster: brand_cluster)
    else
      RunAgent.perform_async("InkBrandClusterer", macro_cluster.id)
    end
  end

  private

  attr_accessor :macro_cluster

  def brand_cluster
    cluster = BrandCluster.find_by(name: macro_cluster.brand_name)
    return cluster if cluster

    BrandCluster
      .joins(:macro_clusters)
      .where(macro_clusters: { brand_name: macro_cluster.brand_name })
      .first
  end
end
