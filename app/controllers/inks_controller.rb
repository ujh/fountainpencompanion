class InksController < ApplicationController
  before_action :authenticate_user!

  def index
    @collected_inks = current_user.collected_inks
    @new_collected_ink = CollectedInk.build
  end

  def create
    @new_collected_ink = current_user.build_collected_ink(params[:collected_ink])
    if @new_collected_ink.valid?
      @new_collected_ink.save
      redirect_to inks_path
    else
      @collected_inks = current_user.collected_inks
      render :index
    end
  end
end
