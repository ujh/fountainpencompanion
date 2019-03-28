class NewInkName < ApplicationRecord

  belongs_to :ink_brand
  has_many :collected_inks

  def self.public
    joins(:collected_inks)
    .where(collected_inks: {private: false})
    .select("new_ink_names.*, count(*) as collected_inks_count")
    .group(:id)
  end

  def self.public_count
    public.unscope(:select).count.count
  end

  def self.empty
    left_joins(:collected_inks).where(collected_inks: {id: nil})
  end

  def self.search_line_names(term)
    public.where("popular_line_name ILIKE ?", "%#{term}%").distinct("new_ink_names.popular_line_name").order(:popular_line_name).pluck(:popular_line_name).reject(&:blank?)
  end

  def self.search_names(term)
    simplified_term = Simplifier.simplify(term.to_s)
    public.where("simplified_name LIKE ?", "%#{simplified_term}%").order(:popular_name).pluck(:popular_name)
  end

  def self.without_color
    where(color: '')
  end

  def self.with_color
    where.not(color: '')
  end

  def collected_inks_with_color
    collected_inks.with_color
  end

  def collected_inks_without_color
    collected_inks.without_color
  end

  def brand_name
    ink_brand.popular_name
  end

  def update_popular_names!
    update(
      popular_name: find_popular_ink_name,
      popular_line_name: find_popular_line_name
    )
  end

  private

  def find_popular_ink_name
    collected_inks.group(:ink_name).order(Arel.sql('count(id) DESC')).limit(1).pluck(:ink_name).first
  end

  def find_popular_line_name
    collected_inks.group(:line_name).order(Arel.sql('count(id) DESC')).limit(1).pluck(:line_name).first
  end
end
