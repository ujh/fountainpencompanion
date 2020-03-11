class CollectedInks::BetaController < ApplicationController
  before_action :authenticate_user!

  def index
    redirect_to collected_inks_path
  end

  def new
    redirect_to new_collected_ink_path
  end

  def edit
    redirect_to edit_collected_ink_path(params[:id])
  end

end
