class LinesController < ApplicationController
  def index
    lines = CollectedInk.field_by_term(:line_name, params[:term])
    render json: lines
  end
end
