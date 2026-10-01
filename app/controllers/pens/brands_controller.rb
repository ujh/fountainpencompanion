class Pens::BrandsController < ApplicationController
  def index
    respond_to do |format|
      format.json do
        brands = PenNamePopularity.autocomplete_search(:brand, params[:term])
        render json: brands
      end
    end
  end
end
