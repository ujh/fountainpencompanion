class Admins::BaseController < ApplicationController
  layout "admin"
  before_action :authenticate_user!
  before_action :authenticate!

  private

  def authenticate!
    return if current_user.admin?

    redirect_to new_user_session_path
  end
end
