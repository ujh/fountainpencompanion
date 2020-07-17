class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
    respond_to do |format|
      format.html
      format.jsonapi {
        user = User.where(id: current_user.id).includes(:collected_inks).first
        render jsonapi: user, include: :collected_inks
      }
    end
  end

  def update
    if current_user.update(accounts_params)
      redirect_to account_path
    else
      render :edit
    end
  end

  private

  def accounts_params
    params.require(:user).permit(:name, :blurb, :time_zone)
  end
end
