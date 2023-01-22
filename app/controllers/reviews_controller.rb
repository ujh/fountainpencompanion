class ReviewsController < ApplicationController
  before_action :authenticate_user!, only: [:my_missing]

  def missing
    @macro_clusters = sorted_clusters(unreviewed_ids)
  end

  def my_missing
    @macro_clusters = sorted_clusters(my_unreviewed_ids)
  end

  private

  def unreviewed_ids
    MacroCluster.without_review.pluck(:id)
  end

  def my_unreviewed_ids
    MacroCluster.without_review_of_user(current_user).pluck(:id)
  end

  def sorted_clusters(ids)
    MacroCluster
      .where(id: ids)
      .joins(micro_clusters: :collected_inks)
      .includes(:brand_cluster)
      .where(collected_inks: { private: false })
      .group("macro_clusters.id")
      .select("macro_clusters.*, count(macro_clusters.id) as ci_count")
      .order("ci_count desc")
      .page(params[:page])
      .per(10)
  end
end
