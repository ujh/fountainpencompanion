class Api::V1::BrandsController < Api::V1::BaseController
  resource_description do
    short "Brands. Autocomplete search for brands"
    formats ["json"]
    description "Endpoints for searching and retrieving available ink and pen brands."
  end

  api :GET, "/api/v1/brands", "Search for brands with autocomplete"
  param :term, String, desc: "Search term to filter brands by name", required: false
  returns code: 200, desc: "A list of matching brands" do
    property :data, array_of: Hash do
      property :id, String, desc: "ID of the brand (brand cluster)"
      property :type, ["brand_cluster"]
      property :attributes, Hash, desc: "Attributes of the brand" do
        property :name, String, desc: "Name of the brand"
      end
    end
  end
  def index
    render json: serializer.serializable_hash.to_json
  end

  private

  def clusters
    BrandCluster.autocomplete_search(params[:term]).order(:name)
  end

  def serializer
    BrandClusterSerializer.new(clusters)
  end
end
