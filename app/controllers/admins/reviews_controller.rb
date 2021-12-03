class Admins::ReviewsController < Admins::BaseController
  def index
    @ink_review = InkReview.queued.order('created_at desc').first
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
    if InkReview.queued.exists?
      redirect_to admins_review_path
    else
      redirect_to admins_dashboard_path
    end
  end
end
