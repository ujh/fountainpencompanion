class BrandsController < ApplicationController
  add_breadcrumb "Inks", "/brands"

  def index
    respond_to do |format|
      format.json do
        clusters = BrandCluster.autocomplete_search(params[:term])
        serializer = BrandClusterSerializer.new(clusters)
        render json: serializer.serializable_hash.to_json
      end
      format.html { @brands = BrandCluster.public.order(:name) }
    end
  end

  def show
    @brand = BrandCluster.find(params[:id])

    add_breadcrumb "#{@brand.name}", brand_path(@brand)

    respond_to do |format|
      format.html do
        @inks =
          @brand
            .macro_clusters
            .public
            .order("line_name, ink_name")
            .select("macro_clusters.*, count(*) as collected_inks_count")
      end
      format.csv do
        send_data @brand.to_csv,
                  type: "text/csv",
                  filename: "#{@brand.name.parameterize}.csv"
      end
    end
  end
end
