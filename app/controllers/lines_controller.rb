class LinesController < ApplicationController
  def index
    lines = Line.where("LOWER(name) LIKE ?", "#{params[:term].downcase}%").order(:name)
    render json: lines.pluck(:name)
  end
end
