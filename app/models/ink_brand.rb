class InkBrand < ApplicationRecord
  has_many :collected_inks

  def self.public
    joins(:collected_inks).where(collected_inks: {private: false}).distinct("ink_brands.popular_name")
  end

  def update_popular_name!
    popular_name = collected_inks.group(:brand_name).order('count(id) DESC').limit(1).pluck(:brand_name).first
    update(popular_name: popular_name)
  end
end
