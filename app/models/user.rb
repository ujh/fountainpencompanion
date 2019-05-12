class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :timeoutable, :trackable, :validatable

  has_many :currently_inkeds, dependent: :destroy
  has_many :collected_inks, dependent: :delete_all
  has_many :collected_pens, dependent: :delete_all
  has_many :usage_records, through: :currently_inkeds

  validates :name, length: { in: 1..100, allow_blank: true }

  def self.active
    where.not(confirmed_at: nil)
  end

  def self.public
    where.not(name: [nil, ""])
  end

  def admin?
    false
  end

  def public_inks
    collected_inks.where(private: false).active.order("brand_name, line_name, ink_name")
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

  def collected_inks_for_select
    collected_inks.order('brand_name, line_name, ink_name')
  end

  def collected_pens_for_select
    collected_pens.order('brand, model, nib, color')
  end

  def active_collected_pens
    collected_pens.active
  end

  def archived_collected_pens
    collected_pens.archived
  end

  def active_collected_inks
    collected_inks.active
  end

end
