class DescriptionsController < ApplicationController
  before_action :authenticate_user!, only: [:my_missing]

  def missing
    @missing_inks = sorted_inks(clusters_without_descriptions_ids, cache: true)
    @missing_brands = sorted_brands(brands_without_descriptions_ids, cache: true)
  end

  def my_missing
    @missing_inks = sorted_inks(my_clusters_without_descriptions_ids)
    @missing_brands = sorted_brands(my_brands_without_descriptions_ids)
  end

  private

  def brands_without_descriptions_ids
    Rails
      .cache
      .fetch("DescriptionsController#brands_without_descriptions_ids", expires_in: 6.hours) do
        BrandCluster.without_description.pluck(:id)
      end
  end

  def my_brands_without_descriptions_ids
    BrandCluster.without_description_of_user(current_user).pluck(:id)
  end

  def clusters_without_descriptions_ids
    Rails
      .cache
      .fetch("DescriptionsController#clusters_without_descriptions_ids", expires_in: 6.hour) do
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

  def sorted_inks(ids, cache: false)
    rel =
      MacroCluster
        .where(id: ids)
        .select(:id, :brand_name, :line_name, :ink_name)
        .order(:brand_name, :line_name, :ink_name)
    rel =
      Rails.cache.fetch("DescriptionsController#sorted_inks", expires_in: 6.hours) { rel } if cache

    rel.page(params[:inks_page]).per(10)
  end

  def sorted_brands(ids, cache: false)
    rel = BrandCluster.where(id: ids).select(:id, :name).group("brand_clusters.id").order(:name)
    rel =
      Rails
        .cache
        .fetch("DescriptionsController#sorted_brands", expires_in: 6.hours) { rel } if cache

    rel.page(params[:brands_page]).per(10)
  end
end
