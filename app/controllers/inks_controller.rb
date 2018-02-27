class InksController < ApplicationController

  def index
    inks = Ink.search(params[:term]).pluck(:popular_ink_name)
    render json: inks
  end
end
