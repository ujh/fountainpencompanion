class BrandsController < ApplicationController
  add_breadcrumb "Inks", "/brands"

  def index
    @brands = BrandCluster.public.order(:name)
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
