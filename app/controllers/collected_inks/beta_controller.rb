class CollectedInks::BetaController < ApplicationController
  before_action :authenticate_user!

  def index
    inks = current_user.collected_inks.order("brand_name, line_name, ink_name")
    respond_to do |format|
      format.html do
        @collection = inks.active
      end
      format.csv do
        send_data inks.to_csv, type: "text/csv", filename: "collected_inks.csv"
      end
    end
  end

  def destroy
    ink = current_user.collected_inks.find_by(id: params[:id])
    if ink
      if ink.deletable?
        ink.destroy
        flash[:notice] = "Ink successfully deleted"
      else
        flash[:alert] = "'#{ink.name}' has currently inked entries attached and can't be deleted."
      end
    end
    redirect_to collected_inks_beta_path
  end
end
