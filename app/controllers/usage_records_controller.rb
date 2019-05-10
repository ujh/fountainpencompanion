class UsageRecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_currently_inked, only: [:create]

  def create
    if @currently_inked
      @currently_inked.usage_records.find_or_create_by(used_on: Date.today)
    end
    head :created
  end

  private

  def retrieve_currently_inked
    @currently_inked = current_user.currently_inkeds.find_by(id: params[:currently_inked_id])
  end
end
