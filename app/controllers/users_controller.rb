class UsersController < ApplicationController

  def show
    @user = User.find(params[:id])
    raise ActiveRecord::RecordNotFound if @user.private?
  end
end
