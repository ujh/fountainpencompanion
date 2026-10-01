class Pens::BrandsController < ApplicationController
  def index
    respond_to do |format|
      format.json do
        brands = PenNamePopularity.autocomplete_search(params[:term], :brand)
        render json: brands
      end
    end
  end
end
