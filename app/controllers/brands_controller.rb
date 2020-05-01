class BrandsController < ApplicationController
  def index
    respond_to do |format|
      format.json {
        clusters = BrandCluster.autocomplete_search(params[:term])
        serializer = BrandClusterSerializer.new(clusters)
        render json: serializer.serializable_hash.to_json
      }
      format.html {
        @brands = InkBrand.public.order(:popular_name)
      }
    end
  end

  def show
    @brand = InkBrand.find(params[:id])
    @inks = @brand.new_ink_names.public.order("popular_line_name, popular_name")
  end

end
