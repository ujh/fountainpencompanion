class LinesController < ApplicationController
  def index
    lines = Line.search(params[:term]).pluck(:popular_line_name).reject(&:blank?)
    render json: lines
  end
end
