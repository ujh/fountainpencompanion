class UsersController < ApplicationController

  def index
    rel = User
    count = [rel.count, 1].max
    @users = rel.order('name').in_groups_of((count.to_f / 3).ceil, false)
  end

  def show
    @user = User.find(params[:id])
  end
end
