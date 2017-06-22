class Admins::UsersController < ApplicationController

  layout 'admin'

  before_action :authenticate_admin!

  def index
    @users = User.all
  end

  def become
    user = User.find(params[:id])
    sign_in(:user, user, bypass: true)
    redirect_to root_url
  end
end
