class Pens::ModelsController < ApplicationController
  def index
    respond_to do |format|
      format.json do
        models = PenNamePopularity.autocomplete_search(:model, params[:term], brand: params[:brand])
        render json: models
      end
    end
  end
end
