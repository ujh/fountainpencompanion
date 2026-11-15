class InkReviewSubmission < ApplicationRecord
  belongs_to :macro_cluster
  belongs_to :user
  belongs_to :ink_review, optional: true

  validates :url, presence: true
  validates :url, uniqueness: { scope: %i[user_id macro_cluster_id], case_sensitive: false }
  validate :url_not_instagram

  scope :unassigned, -> { where(ink_review: nil) }

  private

  def url_not_instagram
    return if url.blank?

    host = URI.parse(url).host&.downcase
    return unless host == "instagram.com" || host&.end_with?(".instagram.com")

    errors.add(
      :url,
      "Instagram URLs are not supported as image previews do not work for Instagram posts"
    )
  rescue URI::InvalidURIError
    # Let other validations handle invalid URIs
  end
end
