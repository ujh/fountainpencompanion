class Pens::BrandsController < ApplicationController

  def index
    respond_to do |format|
      format.json {
        brands = CollectedPen.search(:brand, params[:term])
        render json: brands
      }
    end
  end

end
