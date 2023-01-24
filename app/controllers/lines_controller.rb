class LinesController < ApplicationController
  def index
    clusters = MacroCluster.autocomplete_search(params[:term], :line_name)
    serializer =
      MacroClusterSerializer.new(
        clusters,
        fields: {
          macro_cluster: [:line_name]
        }
      )
    render json: serializer.serializable_hash.to_json
  end
end
