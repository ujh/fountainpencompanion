class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
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
    params.require(:user).permit(:name)
  end
end
