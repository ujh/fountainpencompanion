class Admins::ReviewsController < Admins::BaseController
  def index
    @ink_reviews = InkReview.queued.order('created_at asc').page(params[:page])
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

  def missing
    @macro_clusters = MacroCluster.without_review.joins(
      micro_clusters: :collected_inks
    ).includes(
      :brand_cluster
    ).where(
      collected_inks: { private: false }
    ).group("macro_clusters.id").select(
      "macro_clusters.*, count(macro_clusters.id) as ci_count"
    ).order("ci_count desc").page(params[:page]).per(10)
  end

  private

  def redirect_after_change
    if InkReview.queued.exists?
      redirect_to admins_reviews_path
    else
      redirect_to admins_dashboard_path
    end
  end
end
