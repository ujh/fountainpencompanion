class CollectedInksController < ApplicationController
  before_action :authenticate_user!
  deserializable_resource :collected_ink, only: [:create, :update]

  def index
    if current_user.collected_inks.empty?
      flash.now[:notice] = "Your ink collection is empty. Check out the <a href='/pages/guide'>documentation</a> on how to add some.".html_safe
    end
    inks = current_user.collected_inks.includes(:currently_inkeds).order("brand_name, line_name, ink_name")
    respond_to do |format|
      format.html
      format.jsonapi {
        render jsonapi: inks
      }
      format.csv do
        send_data inks.to_csv, type: "text/csv", filename: "collected_inks.csv"
      end
    end
  end

  def create
    collected_ink = current_user.collected_inks.build
    if SaveCollectedInk.new(collected_ink, collected_ink_params).perform
      render jsonapi: collected_ink
    else
      render jsonapi_errors: collected_ink.errors
    end
  end

  def update
    collected_ink = current_user.collected_inks.find(params[:id])
    if SaveCollectedInk.new(collected_ink, collected_ink_params).perform
      render jsonapi: collected_ink
    else
      render jsonapi_errors: collected_ink.errors
    end
  end

  def destroy
    collected_ink = current_user.collected_inks.find(params[:id])
    collected_ink.destroy
    render jsonapi: collected_ink
  end

  private

  def collected_ink_params
    params.require(:collected_ink).permit(
      :private,
      :ink_name,
      :line_name,
      :brand_name,
      :kind,
      :color,
      :swabbed,
      :used,
      :comment,
      :maker
    )
  end

end
