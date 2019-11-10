class CollectedInks::BetaArchiveController < ApplicationController
  before_action :authenticate_user!

  def index
    @collection = current_user.collected_inks.archived.order("brand_name, line_name, ink_name")
  end
end
