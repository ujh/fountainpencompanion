class CurrentlyInkedController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_currently_inkeds, only: [:index, :edit, :create, :update]
  before_action :retrieve_currently_inked, only: [:edit, :update, :destroy]

  def index
    @currently_inked = CurrentlyInked.new(user: current_user)
  end

  def edit
    render :index
  end

  def create
    @currently_inked = current_user.currently_inkeds.build(currently_inked_params)
    if @currently_inked.save
      redirect_to currently_inked_index_path(anchor: "add-form")
    else
      @elementToScrollTo = "#add-form"
      render :index
    end
  end

  def update
    if @currently_inked.update(currently_inked_params)
      redirect_to currently_inked_index_path(anchor: @currently_inked.id)
    else
      @elementToScrollTo = "##{@currently_inked.id}"
      render :index
    end
  end

  def destroy
    @currently_inked&.destroy
    redirect_to currently_inked_index_path
  end

  private

  def currently_inked_params
    params.require(:currently_inked).permit(
      :collected_ink_id,
      :collected_pen_id,
      :created_at,
      :archived_on,
      :comment
    )
  end

  def retrieve_currently_inkeds
    @currently_inkeds = current_user.currently_inkeds.active.sort_by {|ci| "#{ci.pen_name} #{ci.ink_name}"}
    @archived = current_user.currently_inkeds.archived.order('archived_on, created_at')
  end

  def retrieve_currently_inked
    @currently_inked = current_user.currently_inkeds.find_by(id: params[:id])
  end
end
