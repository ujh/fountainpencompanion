class BrandsController < ApplicationController
  def index
    respond_to do |format|
      format.json {
        clusters = BrandCluster.autocomplete_search(params[:term])
        serializer = BrandClusterSerializer.new(clusters)
        render json: serializer.serializable_hash.to_json
      }
      format.html {
        @brands = BrandCluster.public.order(:name)
      }
    end
  end

  def show
    @brand = BrandCluster.find(params[:id])
    @inks = @brand.macro_clusters.public.order(
      "line_name, ink_name"
    ).select("macro_clusters.*, count(*) as collected_inks_count")
  end

end
