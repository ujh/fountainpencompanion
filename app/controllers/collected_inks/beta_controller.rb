class CollectedInks::BetaController < ApplicationController
  before_action :authenticate_user!
  before_action :find_ink, only: [:edit, :destroy, :archive, :unarchive]

  def index
    inks = current_user.collected_inks.order("brand_name, line_name, ink_name")
    respond_to do |format|
      format.html do
        @collection = archive? ? inks.archived : inks.active
      end
      format.csv do
        send_data inks.to_csv, type: "text/csv", filename: "collected_inks.csv"
      end
    end
  end

  def edit
  end

  def destroy
    if ink
      if ink.deletable?
        ink.destroy
        flash[:notice] = "Ink successfully deleted"
      else
        flash[:alert] = "'#{ink.name}' has currently inked entries attached and can't be deleted."
      end
    end
    redirect_to collected_inks_beta_index_path
  end

  def archive
    flash[:notice] = "Successfully archived '#{ink.name}'" if ink
    ink&.archive!
    redirect_to collected_inks_beta_index_path
  end

  def unarchive
    flash[:notice] = "Successfully unarchived '#{ink.name}'" if ink
    ink&.unarchive!
    redirect_to collected_inks_beta_index_path
  end

  private

  attr_accessor :ink

  def find_ink
    self.ink = current_user.collected_inks.find_by(id: params[:id])
  end

  helper_method :archive?
  def archive?
    params.dig(:search, :archive) == 'true'
  end
end
