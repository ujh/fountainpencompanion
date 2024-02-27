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
    unfiltered_ids = MacroCluster.without_review.pluck(:id)
    clusters_hash = unfiltered_ids.hash
    key = "ReviewsController#unreviewed_ids-#{clusters_hash}"
    Rails
      .cache
      .fetch(key, expires_in: 1.hour) do
        MacroCluster
          .where(id: unfiltered_ids)
          .joins(micro_clusters: :collected_inks)
          .where(collected_inks: { private: false })
          .distinct
          .pluck(:id)
      end
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
