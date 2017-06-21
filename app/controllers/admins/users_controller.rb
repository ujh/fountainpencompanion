class Admins::UsersController < ApplicationController

  layout 'admin'

  before_action :authenticate_admin!

  def index
    @users = User.all
  end
end
