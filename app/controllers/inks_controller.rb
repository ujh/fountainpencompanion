class InksController < ApplicationController
  def index
    render json: NewInkName.search_names(params[:term])
  end
end
