class BrandsController < ApplicationController

  def index
    brands = Brand.where("LOWER(name) LIKE ?", "#{params[:term].downcase}%").order(:name)
    render json: brands.pluck(:name)
  end
end
