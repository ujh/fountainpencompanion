class CollectedInks::BetaArchiveController < ApplicationController
  before_action :authenticate_user!

  def index
    @collection = current_user.collected_inks.archived.order("brand_name, line_name, ink_name")
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
    redirect_to collected_inks_beta_archive_index_path
  end
end
