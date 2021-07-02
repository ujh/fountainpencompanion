class CollectedPensArchiveController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_collected_pens, only: [:index]
  before_action :retrieve_collected_pen, only: [:edit, :update, :destroy, :unarchive]

  def index
  end

  def edit
  end

  def update
    if @collected_pen.update(collected_pen_params)
      redirect_to collected_pens_archive_index_path
    else
      render :edit
    end
  end

  def unarchive
    flash[:notice] = "Successfully unarchived '#{@collected_pen.name}'" if @collected_pen
    @collected_pen&.unarchive!
    redirect_to collected_pens_archive_index_path
  end

  def destroy
    @collected_pen&.destroy
    redirect_to collected_pens_archive_index_path
  end

  private

  def collected_pen_params
    params.require(:collected_pen).permit(
      :brand,
      :model,
      :nib,
      :color,
      :comment,
    )
  end

  def retrieve_collected_pen
    @collected_pen = current_user.collected_pens.find_by!(id: params[:id])
  end

  def retrieve_collected_pens
    @collected_pens = current_user.archived_collected_pens.includes(:currently_inkeds).order('brand, model')
  end
end
