class LinesController < ApplicationController
  def index
    lines = Line.search(params[:term]).pluck(:popular_line_name)
    render json: lines
  end
end
