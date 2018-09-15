class NewInkName < ApplicationRecord

  belongs_to :ink_brand, counter_cache: true
  has_many :collected_inks

  def self.public
    joins(:collected_inks).where(collected_inks: {private: false}).distinct("new_ink_names.popular_name")
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
