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
    Rails
      .cache
      .fetch(
        "DescriptionsController#brands_without_descriptions_ids",
        expires_in: 1.hour
      ) { BrandCluster.without_description.pluck(:id) }
  end

  def my_brands_without_descriptions_ids
    BrandCluster.without_description_of_user(current_user).pluck(:id)
  end

  def clusters_without_descriptions_ids
    Rails
      .cache
      .fetch(
        "DescriptionsController#clusters_without_descriptions_ids",
        expires_in: 1.hour
      ) do
        MacroCluster
          .without_description
          .joins(micro_clusters: :collected_inks)
          .where(collected_inks: { private: false })
          .distinct
          .pluck(:id)
      end
  end

  def my_clusters_without_descriptions_ids
    MacroCluster.without_description_of_user(current_user).pluck(:id)
  end

  def sorted_inks(ids)
    MacroCluster
      .where(id: ids)
      .includes(:brand_cluster)
      .order(:brand_name, :line_name, :ink_name)
      .page(params[:inks_page])
      .per(10)
  end

  def sorted_brands(ids)
    BrandCluster
      .where(id: ids)
      .joins(:macro_clusters)
      .group("brand_clusters.id")
      .order(:name)
      .page(params[:brands_page])
      .per(10)
  end
end
