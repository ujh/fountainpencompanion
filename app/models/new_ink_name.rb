class NewInkName < ApplicationRecord

  belongs_to :ink_brand
  has_many :collected_inks

  def update_popular_name!
    popular_name = collected_inks.group(:ink_name).order(Arel.sql('count(id) DESC')).limit(1).pluck(:ink_name).first
    update(popular_name: popular_name)
  end

end
