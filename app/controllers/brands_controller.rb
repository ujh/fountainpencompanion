class BrandsController < ApplicationController
  def index
    respond_to do |format|
      format.jsonapi {
        brands = InkBrand.public.order(:popular_name)
        render jsonapi: brands
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
