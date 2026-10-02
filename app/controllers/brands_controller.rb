class BrandsController < ApplicationController
  add_breadcrumb "Inks", "/brands"

  before_action :authenticate_user!, only: %i[edit update]
  before_action :set_paper_trail_whodunnit, only: %i[edit update]

  def index
    @brands = BrandCluster.public.order(:name)
  end

  def show
    @brand = BrandCluster.find(params[:id])
    @description = build_description
    add_breadcrumb "#{@brand.name}", brand_path(@brand)

    @inks =
      @brand
        .macro_clusters
        .public
        .order("line_name, ink_name")
        .select("macro_clusters.*, count(*) as collected_inks_count")
  end

  def edit
    @brand = BrandCluster.find(params[:id])
  end

  def update
    @brand = BrandCluster.find(params[:id])
    @brand.update(description: params[:brand_cluster][:description])

    redirect_to brand_path(@brand)
  end

  private

  def build_description
    if @brand.description.present?
      @brand.description.truncate(100)
    else
      "#{@brand.public_ink_count} distinct inks. #{@brand.public_collected_inks_count} entries in total."
    end
  end
end
