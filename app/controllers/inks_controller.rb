class InksController < ApplicationController

  def index
    inks = Rails.cache.fetch('inks', expires_in: 5.minutes) do
      Ink.search(params[:term]).pluck(:popular_ink_name)
    end
    render json: inks
  end
end
