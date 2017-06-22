class BrandsController < ApplicationController
  def index
    brands = CollectedInk.field_by_term(:brand_name, params[:term])
    render json: brands
  end
end
