class Api::V1::InksController < Api::V1::BaseController
  def index
    render json: serializer.serializable_hash.to_json
  end

  private

  def clusters
    MacroCluster.autocomplete_ink_search(params[:term], params[:brand_name])
  end

  def serializer
    MacroClusterSerializer.new(clusters, fields: { macro_cluster: [:ink_name] })
  end
end
