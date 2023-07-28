class InksController < ApplicationController
  before_action :authenticate_user!, only: %i[edit update]
  before_action :set_paper_trail_whodunnit, only: %i[edit update]

  def index
    @clusters = full_text_cluster_search
  end

  def show
    @ink = MacroCluster.find(params[:id])

    add_breadcrumb "Inks", "/brands"
    add_breadcrumb "#{@ink.brand_cluster.name}", brand_path(@ink.brand_cluster)
    add_breadcrumb "#{@ink.name}", brand_ink_path(@ink.brand_cluster, @ink)

    unless params[:brand_id]
      redirect_to brand_ink_path(@ink.brand_cluster, @ink)
    end
  end

  def edit
    @ink = MacroCluster.find(params[:id])
  end

  def update
    @ink = MacroCluster.find(params[:id])
    @ink.update(description: params[:macro_cluster][:description])

    redirect_to ink_path(@ink)
  end

  private

  def full_text_cluster_search
    if params[:q].blank?
      redirect_to brands_path
    else
      MacroCluster.full_text_search(params[:q])
    end
  end
end
