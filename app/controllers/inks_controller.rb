class InksController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_collected_inks

  def index
    @collected_ink = CollectedInk.build
  end

  def create
    @collected_ink = current_user.build_collected_ink(params[:collected_ink])
    if @collected_ink.save
      redirect_to inks_path
    else
      render :index
    end
  end

  def edit
    @collected_ink = current_user.collected_inks.find(params[:id])
    render :index
  end

  def update
    @collected_ink = current_user.update_collected_ink(params)
    if @collected_ink.save
      redirect_to inks_path
    else
      render :index
    end
  end

  def destroy
    current_user.collected_inks.find_by(id: params[:id])&.destroy
    redirect_to inks_path
  end

  private

  def retrieve_collected_inks
    @collected_inks = current_user.collected_inks.joins(ink: :manufacturer).order("manufacturers.name, inks.name")
  end
end
