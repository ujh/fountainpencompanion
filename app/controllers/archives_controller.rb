class ArchivesController < ApplicationController
  before_action :authenticate_user!
  before_action :retrieve_record

  def create
    @record&.update(archived_on: Date.today)
    redirect_to route
  end

  def destroy
    @record&.update(archived_on: nil)
    redirect_to route
  end

  private

  def retrieve_record
    @record = collection.find_by(id: record_id)
  end

  def pen?
    params[:collected_pen_id].present?
  end

  def collection
    pen? ? current_user.collected_pens : current_user.collected_inks
  end

  def record_id
    pen? ? params[:collected_pen_id] : params[:collected_ink_id]
  end

  def route
    pen? ? collected_pens_path : collected_inks_path
  end
end
