class Pens::UpdateBrandCluster
  def initialize(model, brand)
    self.model = model
    self.brand = brand
  end

  def perform
    # Assign all models with the same name to the brand
    Pens::Model.where(brand: model.brand).update_all(pens_brand_id: brand.id)
    brand.update_name!
  end

  private

  attr_accessor :model, :brand
end
