class AccountsController < ApplicationController
  before_action :authenticate_user!

  def show
    respond_to do |format|
      format.html
      format.jsonapi {
        render jsonapi: current_user, include: :collected_inks
      }
    end
  end

  def update
    successful = current_user.update(accounts_params)
    respond_to do |format|
      format.html {
        if successful
          redirect_to account_path
        else
          render :edit
        end
      }
      format.json {
        head :ok
      }
    end
  end

  private

  def accounts_params
    (params['_jsonapi'] ||params).require(:user).permit(:name, :blurb, :time_zone)
  end
end
