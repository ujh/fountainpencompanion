class InksController < ApplicationController
  before_action :authenticate_user!, only: %i[edit update]
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

  def redirect_if_no_search
    return if params[:q].present?
    return if params[:tag].present?

    redirect_to brands_path
  end

  def find_clusters
    if params[:q].present?
      MacroCluster.full_text_search(params[:q])
    else
      collected_inks =
        CollectedInk.where(private: false).tagged_with(names: [params[:tag]])
      MacroCluster
        .distinct
        .joins(micro_clusters: :collected_inks)
        .includes(micro_clusters: :collected_inks)
        .where(collected_inks: { id: collected_inks.pluck(:id) })
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
