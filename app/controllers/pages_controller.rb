class PagesController < ApplicationController
  def show
    if user_signed_in? && params[:id] == "home"
      redirect_to(dashboard_path)
    else
      render template: "pages/#{params[:id]}"
    end
  end
end
