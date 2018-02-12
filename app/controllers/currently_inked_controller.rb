class CurrentlyInkedController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_currently_inkeds, only: [:index, :edit, :create, :update]

  def index
    @currently_inked = CurrentlyInked.new(user: current_user)
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

  private

  def currently_inked_params
    params.require(:currently_inked).permit(
      :collected_ink_id,
      :collected_pen_id,
      :comment
    )
  end

  def retrieve_currently_inkeds
    @currently_inkeds = current_user.currently_inkeds
  end
end
