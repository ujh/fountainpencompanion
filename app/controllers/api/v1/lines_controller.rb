class Api::V1::LinesController < Api::V1::BaseController
  resource_description do
    short "Lines. Autocomplete search for ink lines"
    formats ["json"]
    description "Endpoints for searching and retrieving available ink lines."
  end

  api :GET, "/api/v1/lines", "Search for ink lines with autocomplete"
  param :term, String, desc: "Search term to filter lines by name", required: false
  param :brand_name,
        String,
        desc: "Filter lines by brand name (partial match supported)",
        required: false
  returns code: 200, desc: "A list of matching ink lines" do
    property :data, array_of: Hash do
      property :id, String, desc: "ID of the line (macro cluster)"
      property :type, ["macro_cluster"]
      property :attributes, Hash, desc: "Attributes of the line" do
        property :line_name, String, desc: "Name of the ink line"
      end
    end
  end
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
