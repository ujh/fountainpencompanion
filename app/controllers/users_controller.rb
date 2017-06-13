class UsersController < ApplicationController

  def index
    count = User.count
    @users = User.order('name').in_groups_of((count.to_f / 3).ceil, false)
  end

  def show
    @user = User.find(params[:id])
  end
end
