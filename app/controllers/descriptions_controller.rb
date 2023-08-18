class DescriptionsController < ApplicationController
  before_action :authenticate_user!, only: [:my_missing]

  def missing
    @missing_inks = sorted_inks(clusters_without_descriptions_ids)
    @missing_brands = sorted_brands(brands_without_descriptions_ids)
  end

  def my_missing
    @missing_inks = sorted_inks(my_clusters_without_descriptions_ids)
    @missing_brands = sorted_brands(my_brands_without_descriptions_ids)
  end

  private

  def brands_without_descriptions_ids
    BrandCluster.without_description.pluck(:id)
  end

  def my_brands_without_descriptions_ids
    BrandCluster.without_description_of_user(current_user).pluck(:id)
  end

  def clusters_without_descriptions_ids
    MacroCluster.without_description.pluck(:id)
  end

  def my_clusters_without_descriptions_ids
    MacroCluster.without_description_of_user(current_user).pluck(:id)
  end

  def sorted_inks(ids)
    MacroCluster
      .where(id: ids)
      .joins(micro_clusters: :collected_inks)
      .includes(:brand_cluster)
      .where(collected_inks: { private: false })
      .group("macro_clusters.id")
      .select("macro_clusters.*, count(macro_clusters.id) as ci_count")
      .order("ci_count desc")
      .page(params[:inks_page])
      .per(10)
  end

  def sorted_brands(ids)
    BrandCluster
      .where(id: ids)
      .joins(:macro_clusters)
      .group("brand_clusters.id")
      .select("brand_clusters.*, count(brand_clusters.id) as count")
      .order("count desc")
      .page(params[:brands_page])
      .per(10)
  end
end
