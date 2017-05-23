class CollectedInksController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_collected_inks

  def index
    @collected_ink = CollectedInk.new
  end

  def create
    @collected_ink = current_user.collected_inks.build(collected_ink_params)
    if @collected_ink.save
      redirect_to collected_inks_path
    else
      render :index
    end
  end

  def edit
    @collected_ink = current_user.collected_inks.find(params[:id])
    render :index
  end

  def update
    @collected_ink = current_user.collected_inks.find(params[:id])
    if @collected_ink.update(collected_ink_params)
      redirect_to collected_inks_path
    else
      render :index
    end
  end

  def destroy
    current_user.collected_inks.find_by(id: params[:id])&.destroy
    redirect_to collected_inks_path
  end

  private

  def collected_ink_params
    params.require(:collected_ink).permit(:ink_name, :line_name, :brand_name, :kind)
  end

  def retrieve_collected_inks
    @collected_inks = current_user.collected_inks.order("brand_name, line_name, ink_name")
  end
end
