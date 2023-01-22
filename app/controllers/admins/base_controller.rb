class Admins::BaseController < ApplicationController
  layout "admin"
  before_action :authenticate!

  private

  def authenticate!
    return if current_user&.admin?

    authenticate_admin!
  end
end
