class CurrentlyInkedArchiveController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_currently_inkeds, only: [:index, :edit, :create, :update]
  before_action :retrieve_currently_inked, only: [:edit, :update, :destroy, :unarchive]
  before_action :set_used_pen_ids

  def index
    @currently_inked = CurrentlyInked.new(user: current_user, archived_on: Date.today)
  end

  def edit
    render :index
  end

  def unarchive
    @currently_inked.update(archived_on: nil)
    redirect_to currently_inked_archive_index_path
  end

  def update
    if @currently_inked.update(currently_inked_params)
      @currently_inked.collected_ink.update(used: true)
      redirect_to currently_inked_archive_index_path(anchor: @currently_inked.id)
    else
      @elementToScrollTo = "##{@currently_inked.id}"
      render :index
    end
  end

  def destroy
    @currently_inked.destroy
    redirect_to currently_inked_archive_index_path
  end

  private

  def currently_inked_params
    params.require(:currently_inked).permit(
      :collected_ink_id,
      :collected_pen_id,
      :inked_on,
      :archived_on,
      :comment
    )
  end

  def retrieve_currently_inkeds
    @currently_inkeds = current_user.currently_inkeds.archived.includes(:collected_pen, :collected_ink).order('archived_on DESC, created_at DESC')
  end

  def retrieve_currently_inked
    @currently_inked = current_user.currently_inkeds.find(params[:id])
  end

  def set_used_pen_ids
    @used_pen_ids = current_user.currently_inkeds.active.pluck(:collected_pen_id)
  end
end
