class PossiblyWantedsController < ApplicationController

  before_action :authenticate_user!
  before_action :find_user

  def show
    @possibly_wanted_inks = current_user.possibly_wanted_inks_from(@user).alphabetical
  end

  private

  def find_user
    @user = User.find(params[:user_id])
  end
end
