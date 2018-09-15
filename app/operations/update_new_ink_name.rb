class UpdateNewInkName

  def initialize(collected_ink)
    self.collected_ink = collected_ink
  end

  def perform
    new_ink_name = find_new_ink_name
    collected_ink.update(new_ink_name: new_ink_name)
    new_ink_name.update_popular_names!
  end

  private

  attr_accessor :collected_ink

  THRESHOLD = 2

  def find_new_ink_name
    new_ink_name = NewInkName.where(
      "levenshtein_less_equal(simplified_name, ?, ?) <= ?",
      simplified_name,
      THRESHOLD,
      THRESHOLD
    ).where(ink_brand_id: ink_brand_id).first
    new_ink_name ||= NewInkName.find_or_create_by(
      simplified_name: simplified_name,
      ink_brand_id: ink_brand_id
    )
    new_ink_name
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def simplified_name
    @simplified_name ||= Simplifier.brand(collected_ink.ink_name)
  end

  def ink_brand_id
    @ink_brand_id ||= collected_ink.ink_brand_id
  end

end
