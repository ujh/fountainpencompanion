class Api::V1::LinesController < Api::V1::BaseController
  def index
    render json: serializer.serializable_hash.to_json
  end

  private

  def clusters
    MacroCluster.autocomplete_line_search(params[:term], params[:brand_name])
  end

  def serializer
    MacroClusterSerializer.new(clusters, fields: { macro_cluster: [:line_name] })
  end
end
