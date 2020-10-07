class ReadingStatus < ApplicationRecord
  belongs_to :user
  belongs_to :blog_post

  def self.unread
    where(read: false, dismissed: false)
  end
end
