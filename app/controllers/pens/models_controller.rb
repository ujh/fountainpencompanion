class Pens::ModelsController < ApplicationController
  def index
    respond_to do |format|
      format.json do
        brands = CollectedPen.search(:model, params[:term])
        render json: brands
      end
    end
  end
end
