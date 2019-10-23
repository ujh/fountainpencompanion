class CurrentlyInkedController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_collection, only: [:index, :edit, :create, :update]
  before_action :retrieve_record, only: [:edit, :update, :destroy, :archive]

  def index
    @record = CurrentlyInked.new(user: current_user)
    respond_to do |format|
      format.html
      format.csv do
        cis = current_user.currently_inkeds.includes(:collected_pen, :collected_ink)
        send_data cis.to_csv, type: "text/csv", filename: "currently_inked.csv"
      end
    end
  end

  def edit
    render :index
  end

  def archive
    @record.archive!
    redirect_to currently_inked_index_path
  end

  def create
    @record = current_user.currently_inkeds.build(currently_inked_params)
    if @record.save
      anchor = "add-form"
      redirect_to currently_inked_index_path(anchor: anchor)
    else
      @elementToScrollTo = "#add-form"
      render :index
    end
  end

  def update
    if @record.update(currently_inked_params)
      redirect_to currently_inked_index_path(anchor: @record.id)
    else
      @elementToScrollTo = "##{@record.id}"
      render :index
    end
  end

  def destroy
    @record.destroy
    redirect_to currently_inked_index_path
  end

  private

  def currently_inked_params
    params.require(:currently_inked).permit(
      :collected_ink_id,
      :collected_pen_id,
      :inked_on,
      :comment
    )
  end

  def retrieve_collection
    @collection = current_user.currently_inkeds.active.includes(
      :collected_pen, :collected_ink
    ).sort_by {|ci| "#{ci.pen_name} #{ci.ink_name}"}
  end

  def retrieve_record
    @record = current_user.currently_inkeds.find(params[:id])
  end
end
