class InksController < ApplicationController
  def index
    clusters = MacroCluster.autocomplete_search(params[:term], :ink_name)
    serializer = MacroClusterSerializer.new(
      clusters, fields: { macro_cluster: [:ink_name]}
    )
    render json: serializer.serializable_hash.to_json
  end

  def show
    @ink = MacroCluster.find(params[:id])
    redirect_to brand_ink_path(@ink.brand_cluster, @ink) unless params[:brand_id]
  end
end
