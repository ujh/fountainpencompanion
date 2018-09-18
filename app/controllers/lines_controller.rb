class LinesController < ApplicationController
  def index
    render json: NewInkName.search_line_names(params[:term])
  end
end
