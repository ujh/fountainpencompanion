class InksController < ApplicationController
  before_action :authenticate_user!, only: %i[edit edit_name edit_colors update]
  before_action :set_paper_trail_whodunnit, only: %i[edit update]
  before_action :reject_non_string_tag, only: [:index]
  before_action :redirect_if_no_search, only: [:index]

  def index
    @clusters = find_clusters
  end

  def show
    @ink = MacroCluster.find(params[:id])
    return redirect_to brand_ink_path(@ink.brand_cluster, @ink) unless params[:brand_id]

    @description = build_description
    @ink_reviews = @ink.approved_ink_reviews.to_a
    @loved_ink_review_ids = loved_ink_review_ids(@ink_reviews)
    add_breadcrumb "Inks", "/brands"
    add_breadcrumb "#{@ink.brand_cluster.name}", brand_path(@ink.brand_cluster)
    add_breadcrumb "#{@ink.name}", brand_ink_path(@ink.brand_cluster, @ink)
  end

  def edit
    @ink = MacroCluster.find(params[:id])
  end

  def edit_name
    @ink = MacroCluster.find(params[:id])
  end

  def edit_colors
    @ink = MacroCluster.find(params[:id])
  end

  def update
    @ink = MacroCluster.find(params[:id])
    @ink.update(update_params)
    @ink.ink_embedding&.update(content: @ink.name)

    redirect_to ink_path(@ink)
  end

  private

  def loved_ink_review_ids(ink_reviews)
    return Set.new unless user_signed_in?

    current_user.ink_review_loves.where(ink_review: ink_reviews).pluck(:ink_review_id).to_set
  end

  def update_params
    params.require(:macro_cluster).permit(
      :description,
      :manual_brand_name,
      :manual_line_name,
      :manual_ink_name,
      :line_name_is_empty,
      ignored_colors: []
    )
  end

  def reject_non_string_tag
    head :bad_request if params.key?(:tag) && !params[:tag].is_a?(String)
  end

  def redirect_if_no_search
    return if search_query.present?
    return if params[:tag].present?

    redirect_to brands_path
  end

  def find_clusters
    if search_query.present?
      MacroCluster.full_text_search(search_query)
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
