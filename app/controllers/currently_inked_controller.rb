class CurrentlyInkedController < ApplicationController
  before_action :authenticate_user!
  # TODO: In which actions is that even needed?
  before_action :retrieve_collection, only: [:index, :beta]
  # TODO: In which actions is that even needed?
  before_action :retrieve_record, only: [:edit, :update, :destroy, :archive, :refill]

  def index
    cookies.delete :beta
    respond_to do |format|
      format.html
      format.csv do
        cis = current_user.currently_inkeds.includes(:collected_pen, :collected_ink)
        send_data cis.to_csv, type: "text/csv", filename: "currently_inked.csv"
      end
    end
  end

  def beta
    cookies[:beta] = "it is ON!"
  end

  def edit
  end

  def update
    if @record.update(currently_inked_params)
      flash[:notice] = "Successfully updated entry"
      redirect_to the_index
    else
      render :edit
    end
  end

  def archive
    @record.archive!
    redirect_to the_index
  end

  def refill
    @record.refill!
    flash[:notice] = "Refilled your #{@record.pen_name} with #{@record.ink_name}."
    redirect_to the_index
  end

  def new
    @record = CurrentlyInked.new(inked_on: Date.today, user: current_user)
  end

  def create
    @record = current_user.currently_inkeds.build(currently_inked_params)
    if @record.save
      flash[:notice] = "Successfully created entry"
      redirect_to the_index
    else
      render :new
    end
  end

  def destroy
    @record.destroy
    redirect_to the_index
  end

  private

  def the_index
    if cookies[:beta].present?
      beta_currently_inked_index_path
    else
      currently_inked_index_path
    end
  end

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
