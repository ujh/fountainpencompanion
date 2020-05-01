class BrandsController < ApplicationController
  def index
    respond_to do |format|
      format.json {
        clusters = MacroCluster.brand_search(params[:term])
        serializer = MacroClusterSerializer.new(
          clusters, fields: { macro_cluster: [:brand_name]}
        )
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
