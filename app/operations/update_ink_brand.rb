class UpdateInkBrand

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    ink_brand = find_ink_brand
    collected_ink.update(ink_brand: ink_brand)
    ink_brand.update_popular_name!
  end

  private

  attr_accessor :collected_ink

  def find_ink_brand
    InkBrand.find_or_create_by(simplified_name: simplified_name)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def simplified_name
    Simplifier.simplify(collected_ink.brand_name)
  end
end
