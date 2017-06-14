class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :collected_inks

  validates :name, length: { in: 1..100, allow_blank: true }

  def to_param
    value = "#{id}"
    value << "-#{name.downcase.gsub(/\s/, '-')}" if name.present?
    value
  end

  def public_inks
    collected_inks.where(private: false).order("brand_name, line_name, ink_name")
  end

  def public_name
    private? ? "Anonymous" : name
  end

  def private?
    name.blank?
  end

  def possibly_wanted_inks_from(other_user)
    other_user.collected_inks_intersection(self.collected_inks)
  end

  def possibly_interesting_inks_for(other_user)
    collected_inks_intersection(other_user.public_inks)
  end

  protected

  def collected_inks_intersection(other_user_rel)
    # Join with select query?
    on = %w(brand_name line_name ink_name).map do |column|
      "LOWER(collected_inks.#{column}) = LOWER(ci2.#{column})"
    end.join(" AND ")
    other_user_rel.joins("LEFT OUTER JOIN (#{collected_inks.to_sql}) as ci2 ON #{on}").where("ci2.user_id IS NULL")
  end
end
