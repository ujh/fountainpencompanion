class InksController < ApplicationController
  before_action :authenticate_user!, only: %i[edit edit_name update]
  before_action :set_paper_trail_whodunnit, only: %i[edit update]
  before_action :redirect_if_no_search, only: [:index]

  def index
    @clusters = find_clusters
  end

  def show
    @ink = MacroCluster.find(params[:id])
    @description = build_description
    add_breadcrumb "Inks", "/brands"
    add_breadcrumb "#{@ink.brand_cluster.name}", brand_path(@ink.brand_cluster)
    add_breadcrumb "#{@ink.name}", brand_ink_path(@ink.brand_cluster, @ink)

    redirect_to brand_ink_path(@ink.brand_cluster, @ink) unless params[:brand_id]
  end

  def edit
    @ink = MacroCluster.find(params[:id])
  end

  def edit_name
    @ink = MacroCluster.find(params[:id])
  end

  def update
    @ink = MacroCluster.find(params[:id])
    @ink.update(update_params)
    @ink.ink_embedding&.update(content: @ink.name)

    redirect_to ink_path(@ink)
  end

  private

  def update_params
    params.require(:macro_cluster).permit(
      :description,
      :manual_brand_name,
      :manual_line_name,
      :manual_ink_name,
      ignored_colors: []
    )
  end

  def redirect_if_no_search
    return if params[:q].present?
    return if params[:tag].present?

    redirect_to brands_path
  end

  def find_clusters
    if params[:q].present?
      MacroCluster.full_text_search(params[:q])
    else
      MacroCluster
        .where("? = ANY(tags)", params[:tag])
        .includes(:brand_cluster)
        .order(:brand_name, :line_name, :ink_name)
    end
  end

  def build_description
    if @ink.description.present?
      @ink.description.truncate(100)
    else
      "This ink is owned by #{@ink.public_collected_inks_count} users"
    end
  end
end
