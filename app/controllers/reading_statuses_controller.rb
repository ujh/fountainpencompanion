class ReadingStatusesController < ApplicationController
  before_action :authenticate_user!

  def update
    current_user
      .reading_statuses
      .find_by(id: params[:id])
      &.update(dismissed: true)
  end
end
