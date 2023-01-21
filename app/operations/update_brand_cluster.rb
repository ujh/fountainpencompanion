class UpdateBrandCluster
  def initialize(macro_cluster, brand_cluster)
    self.macro_cluster = macro_cluster
    self.brand_cluster = brand_cluster
  end

  def perform
    # Assign all clusters with the name brand name
    MacroCluster.where(brand_name: macro_cluster.brand_name).update_all(
      brand_cluster_id: brand_cluster.id
    )
    brand_cluster.update_name!
  end

  private

  attr_accessor :brand_cluster
  attr_accessor :macro_cluster
end
