class UpdateInkBrand

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    ink_brand = find_ink_brand
    collected_ink.update(ink_brand: ink_brand)
  end

  private

  attr_accessor :collected_ink

  THRESHOLD = 2

  def find_ink_brand
    ink_brand = InkBrand.where(
      "levenshtein_less_equal(simplified_name, ?, ?) <= ?",
      simplified_name,
      THRESHOLD,
      THRESHOLD
    ).first
    ink_brand ||= InkBrand.find_or_create_by(simplified_name: simplified_name)
    ink_brand
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def simplified_name
    @simplified_name ||= Simplifier.brand(collected_ink.brand_name)
  end
end
