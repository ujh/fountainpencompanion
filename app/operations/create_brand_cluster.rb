class CreateBrandCluster
  def initialize(macro_cluster)
    self.macro_cluster = macro_cluster
  end

  def perform
    brand_cluster = BrandCluster.create!(name: macro_cluster.brand_name)
    # Assign all clusters with the name brand name
    MacroCluster.where(brand_name: macro_cluster.brand_name).update_all(
      brand_cluster_id: brand_cluster.id
    )
    brand_cluster
  end

  private

  attr_accessor :macro_cluster
end
