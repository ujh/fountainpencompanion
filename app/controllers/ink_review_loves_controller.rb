class InkReviewLovesController < ApplicationController
  before_action :authenticate_user!

  def create
    current_user.ink_review_loves.create_or_find_by!(ink_review: ink_review)
    render_love_state(loved: true)
  end

  def destroy
    current_user.ink_review_loves.destroy_by(ink_review: ink_review)
    render_love_state(loved: false)
  end

  private

  def ink_review
    @ink_review ||= InkReview.live.find(params[:ink_review_id])
  end

  def render_love_state(loved:)
    render json: { loved: loved, loves_count: ink_review.reload.loves_count }
  end
end
