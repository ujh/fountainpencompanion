class Pens::CreateBrandCluster
  def initialize(model)
    self.model = model
  end

  def perform
    brand_cluster = Pens::Brand.create!(name: model.brand)
    # Assign all models with the same brand name
    Pens::Model.where(brand: model.brand).update_all(pens_brand_id: brand_cluster.id)
    brand_cluster
  end

  private

  attr_accessor :model
end
