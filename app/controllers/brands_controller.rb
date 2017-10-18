class BrandsController < ApplicationController
  def index
    respond_to do |format|
      format.json {
        brands = CollectedInk.field_by_term(:brand_name, params[:term], current_user)
        render json: brands
      }
      format.html {
        @brands = CollectedInk.unique_brands
      }
    end
  end

  def show
    @inks = CollectedInk.unique_for_brand(params[:id])
  end

end
