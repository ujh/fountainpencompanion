class YouTubeChannel < ApplicationRecord
  has_many :ink_reviews

  def self.channel_ids_for_reviews
    joins(:ink_reviews)
      .where.not(ink_reviews: { approved_at: nil })
      .group(:channel_id)
      .having("count(ink_reviews.id) >= 3")
      .pluck(:channel_id)
  end

  def self.channel_ranking
    joins(:ink_reviews)
      .where.not(ink_reviews: { approved_at: nil })
      .group(:channel_id)
      .order("review_count desc")
      .select(
        "channel_id, count(*) as review_count, min(ink_reviews.author) as channel_name"
      )
  end
end
