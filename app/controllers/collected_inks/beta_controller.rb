class CollectedInks::BetaController < ApplicationController
  before_action :authenticate_user!

  def index
    inks = current_user.collected_inks.order("brand_name, line_name, ink_name")
    respond_to do |format|
      format.html do
        @collection = inks
      end
      format.csv do
        send_data inks.to_csv, type: "text/csv", filename: "collected_inks.csv"
      end
    end
  end

end
