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
      format.json
      format.csv do
        csv = CSV.generate(col_sep: ";") do |csv|
          csv << ["Brand", "Line", "Name", "Type", "Color", "Swabbed", "Used", "Comment"]
          @collected_inks.each {|ci| csv << [ci.brand_name, ci.line_name, ci.ink_name, ci.kind, ci.color, ci.swabbed, ci.used, ci.comment]}
        end
        send_data csv, type: "text/csv", filename: "collected_inks.csv"
      end
    end
  end

  def create
    @collected_ink = current_user.collected_inks.build
    if SaveCollectedInk.new(@collected_ink, collected_ink_params).perform
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
    if SaveCollectedInk.new(@collected_ink, collected_ink_params).perform
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
      :color,
      :swabbed,
      :used,
      :comment,
    )
  end

  def retrieve_collected_inks
    @collected_inks = current_user.collected_inks.order("brand_name, line_name, ink_name")
  end
end
