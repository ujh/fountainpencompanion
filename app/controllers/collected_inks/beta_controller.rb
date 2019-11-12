class CollectedInks::BetaController < ApplicationController
  before_action :authenticate_user!
  before_action :find_ink, only: [:edit, :update, :destroy, :archive, :unarchive]

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

  def new
    self.ink = current_user.collected_inks.build
  end

  def create
    self.ink = current_user.collected_inks.build(collected_ink_params)
    if ink.save
      flash[:notice] = 'Successfully created ink'
      redirect_to collected_inks_beta_index_path
    else
      render :new
    end
  end

  def edit
  end

  def update
    if ink.update(collected_ink_params)
      flash[:notice] = 'Successfully updated ink'
      redirect_to collected_inks_beta_index_path
    else
      render :edit
    end
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
    self.ink = current_user.collected_inks.find(params[:id])
  end

  helper_method :archive?
  def archive?
    params.dig(:search, :archive) == 'true'
  end

  def collected_ink_params
    params.require(:collected_ink).permit(
      :brand_name,
      :line_name,
      :ink_name,
      :maker,
      :kind,
      :swabbed,
      :used,
      :comment,
      :color,
      :private,
    )
  end
end
