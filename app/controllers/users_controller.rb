class UsersController < ApplicationController

  def index
    @users = User.active.order('lower(name), id')
  end

  def show
    @user = User.find(params[:id])
  end
end
