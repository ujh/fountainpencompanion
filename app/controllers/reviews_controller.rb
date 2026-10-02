class ReviewsController < ApplicationController
  include PaginatesCachedIds

  before_action :authenticate_user!, only: [:my_missing]
  before_action :set_percentage

  def missing
    @macro_clusters = paginate_ids(MissingReviews.sorted_ids, MacroCluster.all, :page, per_page: 10)
  end

  def my_missing
    @macro_clusters = sorted_clusters(my_unreviewed_ids)
  end

  private

  def set_percentage
    @percentage = MissingReviews.percentage
  end

  def my_unreviewed_ids
    MacroCluster.without_review_of_user(current_user).pluck(:id)
  end

  def sorted_clusters(ids)
    MacroCluster
      .where(id: ids)
      .includes(:brand_cluster)
      .order(:brand_name, :line_name, :ink_name)
      .page(params[:page])
      .per(10)
  end
end
