class InksController < ApplicationController
  before_action :authenticate_user!

  def index
    @collected_inks = current_user.collected_inks
  end
end
