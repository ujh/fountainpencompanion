class InksController < ApplicationController
  def index
    respond_to do |format|
      format.all { @clusters = full_text_cluster_search }
      format.json {
        clusters = MacroCluster.autocomplete_ink_search(params[:term], params[:brand_name])
        serializer = MacroClusterSerializer.new(
          clusters, fields: { macro_cluster: [:ink_name]}
        )
        render json: serializer.serializable_hash.to_json
      }
      format.html { @clusters = full_text_cluster_search }
    end
  end

  def show
    @ink = MacroCluster.find(params[:id])

    add_breadcrumb "Inks", "/brands"
    add_breadcrumb "#{@ink.brand_cluster.name}", brand_path(@ink.brand_cluster)
    add_breadcrumb "#{@ink.name}", brand_ink_path(@ink.brand_cluster, @ink)

    redirect_to brand_ink_path(@ink.brand_cluster, @ink) unless params[:brand_id]
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
