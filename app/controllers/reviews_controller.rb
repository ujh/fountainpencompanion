class ReviewsController < ApplicationController
  def missing
    unreviewed_ids = MacroCluster.without_review.pluck(:id)
    @macro_clusters = MacroCluster.where(id: unreviewed_ids).joins(
      micro_clusters: :collected_inks
    ).includes(
      :brand_cluster
    ).where(
      collected_inks: { private: false }
    ).group("macro_clusters.id").select(
      "macro_clusters.*, count(macro_clusters.id) as ci_count"
    ).order("ci_count desc").page(params[:page]).per(10)
  end
end
