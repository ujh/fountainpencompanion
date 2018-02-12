class CurrentlyInkedController < ApplicationController
  before_action :authenticate_user!

  def index
    @currently_inkeds = current_user.currently_inkeds
  end

end
