class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :collected_inks
  has_many :collected_pens
  has_many :currently_inkeds

  validates :name, length: { in: 1..100, allow_blank: true }

  def self.active
    where.not(confirmed_at: nil)
  end

  def admin?
    false
  end

  def to_param
    value = "#{id}"
    value << "-#{name.downcase.gsub(/\s/, '-')}" if name.present?
    value
  end

  def public_inks
    collected_inks.where(private: false).order("brand_name, line_name, ink_name")
  end

  def public_count
    public_inks.count
  end

  def public_bottle_count
    public_inks.bottles.count
  end

  def public_sample_count
    public_inks.samples.count
  end

  def public_cartridge_count
    public_inks.cartridges.count
  end

  def public_name
    private? ? "Anonymous" : name
  end

  def brand_count
    collected_inks.group(:brand_name).size.size
  end

  def ink_count
    collected_inks.count
  end

  def bottle_count
    collected_inks.bottles.count
  end

  def sample_count
    collected_inks.samples.count
  end

  def cartridge_count
    collected_inks.cartridges.count
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

  def collected_inks_for_select
    collected_inks.order('brand_name, line_name, ink_name')
  end

  def collected_pens_for_select(currently_inked)
    collected_pens.order('brand, model, nib, color')
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
