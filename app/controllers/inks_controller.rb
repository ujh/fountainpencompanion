class InksController < ApplicationController

  def index
    inks = CollectedInk.field_by_term(:ink_name, params[:term], current_user)
    render json: inks
  end
end
