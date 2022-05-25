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
    respond_to do |format|
      format.html {
        @inks = @brand.macro_clusters.public.order(
          "line_name, ink_name"
        ).select("macro_clusters.*, count(*) as collected_inks_count")
      }
      format.csv {
        send_data @brand.to_csv, type: "text/csv", filename: "#{@brand.name.parameterize}.csv"
      }
    end
  end

end
