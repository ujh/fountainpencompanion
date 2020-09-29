class CheckBrandCluster
  include Sidekiq::Worker

  def perform(id)
    self.cluster = MacroCluster.find(id)
    return if cluster.brand_name == brand_cluster.name

    new_brand_cluster = BrandCluster.where.not(
      id: brand_cluster.id
    ).where(name: cluster.brand_name).first
    cluster.update!(brand_cluster: new_brand_cluster) if new_brand_cluster
  end

  private

  attr_accessor :cluster

  def brand_cluster
    cluster.brand_cluster
  end
end
