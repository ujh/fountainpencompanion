class Friendship < ApplicationRecord
  belongs_to :friend, class_name: 'User'
  belongs_to :sender, class_name: 'User'

  validates :friend, uniqueness: { scope: :sender_id }
  validate :no_duplicate_requests
  validate :two_users

  private

  def no_duplicate_requests
    errors.add(:friend, 'Friend already sent request') if self.class.find_by(sender: friend, friend: sender)
  end

  def two_users
    errors.add(:friend, 'You cannot friend yourself') if sender == friend
  end
end
