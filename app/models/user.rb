class User < ApplicationRecord

  BLACKLIST = ['51.91.67.153']
  MAX_SAME_IP_24H = 2
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :timeoutable, :trackable, :validatable

  has_many :currently_inkeds, dependent: :destroy
  has_many :collected_inks, dependent: :delete_all
  has_many :collected_pens, dependent: :delete_all
  has_many :usage_records, through: :currently_inkeds
  has_many :reading_statuses, dependent: :destroy

  validates :name, length: { in: 1..100, allow_blank: true }

  before_create :check_if_we_should_skip_confirmation

  def self.active
    where.not(confirmed_at: nil)
  end

  def self.public
    where.not(name: [nil, ""])
  end

  def self.bots
    where(bot: true)
  end

  attr_reader :bot_field

  def bot_field=(value)
    return if persisted?

    if value.present? && value != '0'
      self.bot = true
      self.bot_reason = "bot_field (#{value.inspect})"
    end
  end

  def sign_up_ip=(value)
    if BLACKLIST.include?(value)
      self.bot = true
      self.bot_reason = 'sign_up_ip_blacklist'
    end
    ip_count = self.class.where('created_at > ?', 24.hours.ago).where(sign_up_ip: value).count
    if ip_count >= MAX_SAME_IP_24H
      self.bot = true
      self.bot_reason = 'sign_up_ip_24h_timeframe'
    end
    super
  end

  def unread
    reading_statuses.unread.includes(:blog_post)
  end

  def friends
    possible_and_approved_friends.where(
      'friendships.approved = TRUE OR sf.approved = TRUE'
    )
  end

  def friendship_with(friend_id)
    Friendship.where(
      '(friend_id = :friend_id AND sender_id = :user_id) OR (friend_id = :user_id AND sender_id = :friend_id)',
      friend_id: friend_id, user_id: id
    ).first
  end

  def friendship_state_for(user)
    return "friend" if friend?(user)
    return "to-approve" if to_approve?(user)
    return "waiting-for-approval" if waiting_for_approval?(user)
    "no-friend"
  end

  def friend?(user)
    friends.where(id: user.id).exists?
  end

  def pending_friendships
    possible_and_approved_friends.where(
      'friendships.approved = FALSE OR sf.approved = FALSE'
    )
  end

  def waiting_for_approval?(user)
    friendship = friendship_with(user.id)
    friendship && friendship.approved? == false && friendship.sender == self
  end

  def to_approve?(user)
    friendship = friendship_with(user.id)
    friendship && friendship.approved? == false && friendship.friend == self
  end

  def pending_friendship?(user)
    pending_friendships.where(id: user.id).exists?
  end


  def admin?
    Admin.find_by(email: email).present?
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

  private

  def possible_and_approved_friends
    User.joins(
      'LEFT JOIN friendships ON users.id = friendships.friend_id'
    ).joins(
      'LEFT JOIN friendships AS sf ON users.id = sf.sender_id'
    ).where('friendships.sender_id = :id OR sf.friend_id = :id', id: id)
  end

  def check_if_we_should_skip_confirmation
    skip_confirmation_notification! if bot?
  end
end
