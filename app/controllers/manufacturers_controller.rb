class ManufacturersController < ApplicationController

  def index
    manufacturers = Manufacturer.where("LOWER(name) LIKE ?", "#{params[:term].downcase}%").order(:name)
    render json: manufacturers.pluck(:name)
  end
end
