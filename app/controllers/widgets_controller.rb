class WidgetsController < ApplicationController
  before_action :authenticate_user!

  def show
    case params[:id]
    when 'inks_summary'
      render json: inks_summary_data
    when 'pens_summary'
      render json: pens_summary_data
    when 'currently_inked_summary'
      render json: currently_inked_summary_data
    else
      head :unprocessable
    end
  end

  private

  def inks_summary_data
    as_json_api('inks_summary') do
      {
        count: current_user.collected_inks.active.count,
        used: current_user.collected_inks.active.where(used: true).count,
        swabbed: current_user.collected_inks.active.where(swabbed: true).count,
        archived: current_user.collected_inks.archived.count
      }
    end
  end

  def pens_summary_data
    as_json_api('pens_summary') do
      {
        count: current_user.collected_pens.active.count,
        archived: current_user.collected_pens.archived.count
      }
    end
  end

  def currently_inked_summary_data
    as_json_api('currently_inked_summary') do
      {
        active: current_user.currently_inkeds.active.count,
        total: current_user.currently_inkeds.count,
        usage_records: current_user.usage_records.count
      }
    end
  end

  def as_json_api(name)
    {
      data: {
        type: 'widget',
        id: name,
        attributes: yield
      }
    }
  end
end
