class UsersController < ApplicationController

  def index
    rel = user_signed_in? ? User.where("id <> ?", current_user.id) : User
    count = rel.count
    @users = rel.order('name').in_groups_of((count.to_f / 3).ceil, false)
  end

  def show
    @user = User.find(params[:id])
  end
end
