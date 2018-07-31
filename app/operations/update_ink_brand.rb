class UpdateInkBrand

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    ink_brand = InkBrand.find_or_create_by(simplified_name: collected_ink.simplified_brand_name)
    collected_ink.update(ink_brand: ink_brand)
    ink_brand.update_popular_name!
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  private

  attr_accessor :collected_ink

end
