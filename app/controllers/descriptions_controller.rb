class DescriptionsController < ApplicationController
  include PaginatesCachedIds

  before_action :authenticate_user!, only: [:my_missing]

  PER_PAGE = 10

  def missing
    @missing_inks =
      paginate_ids(
        clusters_without_descriptions_ids,
        MacroCluster.select(:id, :brand_name, :line_name, :ink_name),
        :inks_page,
        per_page: PER_PAGE
      )
    @missing_brands =
      paginate_ids(
        brands_without_descriptions_ids,
        BrandCluster.select(:id, :name),
        :brands_page,
        per_page: PER_PAGE
      )
  end

  def my_missing
    @missing_inks = sorted_inks(my_clusters_without_descriptions_ids)
    @missing_brands = sorted_brands(my_brands_without_descriptions_ids)
  end

  private

  # Sorted by name. Cached, as this page gets crawled a lot.
  def brands_without_descriptions_ids
    Rails
      .cache
      .fetch(
        "DescriptionsController#sorted_brands_without_descriptions_ids",
        expires_in: 6.hours
      ) { BrandCluster.without_description.order(:name).pluck(:id) }
  end

  def my_brands_without_descriptions_ids
    BrandCluster.without_description_of_user(current_user).pluck(:id)
  end

  # Sorted by name. Cached, as this page gets crawled a lot.
  def clusters_without_descriptions_ids
    Rails
      .cache
      .fetch(
        "DescriptionsController#sorted_clusters_without_descriptions_ids",
        expires_in: 6.hours
      ) do
        MacroCluster
          .without_description
          .where(
            id:
              MicroCluster
                .joins(:collected_inks)
                .where(collected_inks: { private: false })
                .select(:macro_cluster_id)
          )
          .order(:brand_name, :line_name, :ink_name)
          .pluck(:id)
      end
  end

  def my_clusters_without_descriptions_ids
    MacroCluster.without_description_of_user(current_user).pluck(:id)
  end

  def sorted_inks(ids)
    MacroCluster
      .where(id: ids)
      .select(:id, :brand_name, :line_name, :ink_name)
      .order(:brand_name, :line_name, :ink_name)
      .page(params[:inks_page])
      .per(PER_PAGE)
  end

  def sorted_brands(ids)
    BrandCluster
      .where(id: ids)
      .select(:id, :name)
      .group("brand_clusters.id")
      .order(:name)
      .page(params[:brands_page])
      .per(PER_PAGE)
  end
end
