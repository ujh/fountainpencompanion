class AuthenticationToken < ApplicationRecord
  belongs_to :user

  has_secure_password :token, reset_token: false

  validates :name, presence: true, length: { maximum: 100 }

  after_initialize -> { self.token = SecureRandom.base58(36) if new_record? && token_digest.blank? }

  def access_token
    return unless id && token

    [id, token].join(".")
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end
end
