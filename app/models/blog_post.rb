class BlogPost < ApplicationRecord

  scope :published, -> { where.not(published_at: nil) }

  validates :title, presence: true
  validates :body, presence: true

  def published?
    published_at.present?
  end

  def html_body
    Slodown::Formatter.new(body).complete.to_s.html_safe
  end
end
