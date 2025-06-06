class User < ApplicationRecord
  MAX_SAME_IP_24H = 4

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :registerable,
         :confirmable,
         :recoverable,
         :rememberable,
         :trackable,
         :validatable,
         :magic_link_authenticatable

  has_many :currently_inkeds, dependent: :destroy
  has_many :collected_inks, dependent: :delete_all
  has_many :collected_pens, dependent: :delete_all
  has_many :usage_records, through: :currently_inkeds
  has_many :reading_statuses, dependent: :destroy
  has_many :ink_review_submissions, dependent: :destroy
  has_many :leader_board_rows, dependent: :destroy

  validates :name, length: { in: 1..100, allow_blank: true }

  before_save :check_if_we_should_skip_confirmation

  def self.active
    where.not(confirmed_at: nil)
  end

  def self.public
    where.not(name: [nil, ""]).where(spam: false)
  end

  def self.bots
    where(bot: true)
  end

  def self.spammer
    where(spam: true)
  end

  def self.not_spam
    where(spam: false)
  end

  def self.to_review
    where(review_blurb: true)
  end

  def self.admins
    where(admin: true)
  end

  def active_for_authentication?
    super and !spam?
  end

  def sign_up_ip=(value)
    ip_count = self.class.where("created_at > ?", 24.hours.ago).where(sign_up_ip: value).count
    if ip_count >= MAX_SAME_IP_24H
      self.bot = true
      self.bot_reason = "sign_up_ip_24h_timeframe"
    end
    super
  end

  def after_confirmation
    update_attribute(:bot, false)
  end

  def unread
    reading_statuses.unread.includes(:blog_post)
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
    collected_inks.order("brand_name, line_name, ink_name")
  end

  def collected_pens_for_select
    collected_pens.order("brand, model, nib, color")
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

  def inks_without_reviews?
    MacroCluster.without_review_of_user(self).count > 0
  end

  def brands_or_inks_without_description?
    BrandCluster.without_description_of_user(self).count > 0 or
      MacroCluster.without_description_of_user(self).count > 0
  end

  protected

  def send_devise_notification(notification, *)
    devise_mailer.send(notification, self, *).deliver_later
  end

  private

  def check_if_we_should_skip_confirmation
    skip_confirmation_notification! if bot?
  end
end
