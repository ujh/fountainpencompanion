class InkBrand < ApplicationRecord
  has_many :new_ink_names
  has_many :collected_inks, through: :new_ink_names

  def self.public
    joins(:collected_inks)
    .where(collected_inks: {private: false})
    .select("ink_brands.*, count(distinct new_ink_names.id) as new_ink_names_count")
    .group(:id)
  end

  def self.public_count
    public.unscope(:select).count.count
  end

  def self.empty
    left_joins(:new_ink_names).where(new_ink_names: {id: nil})
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
