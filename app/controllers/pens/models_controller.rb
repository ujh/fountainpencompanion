class Pens::ModelsController < ApplicationController
  before_action :authenticate_user!

  def index
    respond_to do |format|
      format.json do
        models =
          PenNamePopularity.autocomplete_search(
            params[:term],
            :model,
            user: current_user,
            brand: params[:brand]
          )
        render json: models
      end
    end
  end
end
