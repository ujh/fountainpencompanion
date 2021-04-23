class WidgetsController < ApplicationController
  before_action :authenticate_user!

  def show
    case params[:id]
    when 'inks_summary'
      render json: inks_summary_data
    when 'pens_summary'
      render json: pens_summary_data
    else
      head :unprocessable
    end
  end

  private

  def inks_summary_data
    { data: {
      type: 'widget',
      id: 'inks_summary',
      attributes: {
        count: current_user.collected_inks.active.count,
        used: current_user.collected_inks.active.where(used: true).count,
        swabbed: current_user.collected_inks.active.where(swabbed: true).count,
        archived: current_user.collected_inks.archived.count
      }
    }}
  end

  def pens_summary_data
    { data: {
      type: 'widget',
      id: 'ipens_summary',
      attributes: {
        count: current_user.collected_pens.active.count,
        archived: current_user.collected_pens.archived.count
      }
    }}
  end

end
