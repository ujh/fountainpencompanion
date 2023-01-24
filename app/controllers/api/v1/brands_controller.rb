class Api::V1::BrandsController < Api::V1::BaseController
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
