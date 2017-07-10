class PossiblyInterestingsController < ApplicationController

  before_action :authenticate_user!
  before_action :find_user

  def show
    @possibly_interesting_inks = current_user.possibly_interesting_inks_for(@user).alphabetical
  end

  private

  def find_user
    @user = User.find(params[:user_id])
  end
end
