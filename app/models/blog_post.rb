class BlogPost < ApplicationRecord
  has_many :reading_statuses, dependent: :destroy

  scope :published, -> { where.not(published_at: nil) }

  validates :title, presence: true
  validates :body, presence: true

  def published?
    published_at.present?
  end

  def html_body
    FpcFormatter.render(body)
  end

  def first_image
    body =~ /!\[.*\]\((.*)\)/
    $1
  end

  def to_param
    "#{id}-#{title.parameterize}"
  end
end
