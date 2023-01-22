class Admins::ReviewsController < Admins::BaseController
  def index
    query = InkReview.queued.order("created_at asc")
    @ink_reviews = query.page(params[:page])
    @ink_reviews = query.page(0) if @ink_reviews.empty?
  end

  def destroy
    @ink_review = InkReview.find(params[:id])
    @ink_review.reject!
    redirect_after_change
  end

  def update
    @ink_review = InkReview.find(params[:id])
    @ink_review.approve!
    redirect_after_change
  end

  private

  def redirect_after_change
    if request.referrer.blank? || request.referrer =~ %r{/admins}
      if InkReview.queued.exists?
        redirect_to admins_reviews_path(page: params[:page])
      else
        redirect_to admins_dashboard_path
      end
    else
      redirect_to request.referrer
    end
  end
end
