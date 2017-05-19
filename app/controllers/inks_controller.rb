class InksController < ApplicationController

  def index
    inks = Ink.where("LOWER(name) LIKE ?", "#{params[:term].downcase}%").order(:name)
    render json: inks.pluck(:name)
  end
end
