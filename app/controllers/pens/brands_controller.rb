class Pens::BrandsController < ApplicationController
  before_action :authenticate_user!

  def index
    respond_to do |format|
      format.json do
        brands = PenNamePopularity.autocomplete_search(params[:term], :brand)
        render json: brands
      end
    end
  end
end
