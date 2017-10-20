class Brand < ApplicationRecord

  def self.search(term)
    simplified_term = Simplifier.simplify(term.to_s)
    where("simplified_brand_name LIKE ?", "%#{simplified_term}%").order(:popular_name)
  end
end
