class BrandsController < ApplicationController
  def index
    brands = CollectedInk.where("LOWER(brand_name) LIKE ?", "#{params[:term].downcase}%").group(:brand_name).order(:brand_name)
    render json: brands.pluck(:brand_name)
  end
end
