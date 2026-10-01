class Pens::NibsController < ApplicationController
  before_action :authenticate_user!

  def index
    respond_to do |format|
      format.json do
        nibs = current_user.collected_pens.autocomplete_search(:nib, params[:term])
        render json: nibs
      end
    end
  end
end
