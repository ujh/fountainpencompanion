class ReadingStatus < ApplicationRecord
  belongs_to :user
  belongs_to :blog_post

  scope :unread, -> { where(read: false, dismissed: false) }
  scope :read, -> { where(read: true) }
  scope :dismissed, -> { where(dismissed: true) }
end
