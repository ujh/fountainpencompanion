class Ink < ApplicationRecord

  belongs_to :brand, foreign_key: :simplified_brand_name, primary_key: :simplified_brand_name

  def self.search(term)
    simplified_term = Simplifier.simplify(term)
    where("simplified_ink_name LIKE ?", "%#{simplified_term}%").group(:popular_ink_name).order(:popular_ink_name)
  end

  def popular_brand_name
    brand.popular_name
  end

  def popular_line_name
    CollectedInk.where(
      simplified_brand_name: simplified_brand_name,
      simplified_ink_name: simplified_ink_name
    )
    .group(:line_name)
    .order("count(*) desc")
    .limit(1)
    .pluck(:line_name)
    .first
  end
end
