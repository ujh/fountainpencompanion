class CheckBrandClusters
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  def perform(ids = nil)
    if ids.present?
      Array(ids).each { |id| check_cluster(id) }
    else
      MacroCluster
        .pluck(:id)
        .in_groups_of(50, false) { |ids| CheckBrandClusters.perform_async(ids) }
    end
  end

  private

  def check_cluster(id)
    cluster = MacroCluster.find_by(id:)
    return unless cluster

    brand_cluster = cluster.brand_cluster
    return if brand_cluster.blank?
    return if cluster.brand_name == brand_cluster.name

    new_brand_cluster =
      BrandCluster
        .where.not(id: brand_cluster.id)
        .where(name: cluster.brand_name)
        .first
    cluster.update!(brand_cluster: new_brand_cluster) if new_brand_cluster
  end
end
