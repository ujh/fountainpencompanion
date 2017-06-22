class PrivaciesController < ApplicationController
  before_action :authenticate_user!

  def create
    collected_ink.update_attributes(private: true)
    redirect_to collected_inks_url(anchor: collected_ink.id)
  end

  def destroy
    collected_ink.update_attributes(private: false)
    redirect_to collected_inks_url(anchor: collected_ink.id)
  end

  private

  def collected_ink
    current_user.collected_inks.find(params[:collected_ink_id])
  end
end
