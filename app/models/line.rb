class Line < ApplicationRecord
  belongs_to :brand, foreign_key: :simplified_brand_name, primary_key: :simplified_brand_name

  def self.search(term)
    simplified_term = Simplifier.simplify(term)
    where("simplified_line_name LIKE ?", "%#{simplified_term}%").group(:popular_line_name).order(:popular_line_name)
  end

end
