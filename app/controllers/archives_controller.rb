class ArchivesController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_record

  def create
    @record&.update(archived_on: Date.today)
    redirect_to collected_pens_path
  end

  def destroy
    @record&.update(archived_on: nil)
    redirect_to collected_pens_path
  end

  private

  def retrieve_record
    if params[:collected_pen_id]
      @record = current_user.collected_pens.find_by(id: params[:collected_pen_id])
    end
  end
end
