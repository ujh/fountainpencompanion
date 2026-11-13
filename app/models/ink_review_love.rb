class InkReviewLove < ApplicationRecord
  belongs_to :ink_review, counter_cache: :loves_count
  belongs_to :user
end
