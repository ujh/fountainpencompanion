class InkBrand < ApplicationRecord
  has_many :new_ink_names
  has_many :collected_inks, through: :new_ink_names

  def self.public
    joins(:collected_inks)
    .where("new_ink_names_count > 0")
    .where(collected_inks: {private: false})
    .distinct("ink_brands.popular_name")
  end

  def self.search(term)
    simplified_term = Simplifier.simplify(term.to_s)
    public.where("ink_brands.simplified_name LIKE ?", "%#{simplified_term}%").order(:popular_name)
  end

  def update_popular_name!
    popular_name = collected_inks.group(:brand_name).order(Arel.sql('count(collected_inks.id) DESC')).limit(1).pluck(:brand_name).first
    update(popular_name: popular_name)
  end
end
