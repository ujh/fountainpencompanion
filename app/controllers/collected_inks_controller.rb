require 'csv'

class CollectedInksController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_collected_inks

  def index
    if current_user.collected_inks.empty?
      flash.now[:notice] = "Your ink collection is empty. Check out the <a href='/pages/documentation'>documentation</a> on how to add some.".html_safe
    end
    respond_to do |format|
      format.html { @collected_ink = CollectedInk.new }
      format.csv do
        csv = CSV.generate(col_sep: ";") do |csv|
          csv << ["Brand", "Line", "Name", "Type"]
          @collected_inks.each {|ci| csv << [ci.brand_name, ci.line_name, ci.ink_name, ci.kind]}
        end
        send_data csv, type: "text/csv", filename: "collected_inks.csv"
      end
    end
  end

  def create
    @collected_ink = current_user.collected_inks.build(collected_ink_params)
    if @collected_ink.save
      redirect_to collected_inks_path(anchor: "add-form")
    else
      @elementToScrollTo = "#add-form"
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
      redirect_to collected_inks_path(anchor: @collected_ink.id)
    else
      @elementToScrollTo = "##{@collected_ink.id}"
      render :index
    end
  end

  def destroy
    current_user.collected_inks.find_by(id: params[:id])&.destroy
    redirect_to collected_inks_path
  end

  private

  def collected_ink_params
    params.require(:collected_ink).permit(
      :ink_name,
      :line_name,
      :brand_name,
      :kind,
      :comment,
    )
  end

  def retrieve_collected_inks
    @collected_inks = current_user.collected_inks.order("brand_name, line_name, ink_name")
  end
end
