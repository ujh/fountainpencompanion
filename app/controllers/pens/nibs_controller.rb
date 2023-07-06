class Pens::NibsController < ApplicationController
  before_action :authenticate_user!

  def index
    respond_to do |format|
      format.json do
        brands = current_user.collected_pens.search(:nib, params[:term])
        render json: brands
      end
    end
  end
end
