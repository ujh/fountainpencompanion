class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  around_action :set_time_zone

  if !Rails.env.development?
    rescue_from ActionView::MissingTemplate do |exception|
      render file: "public/404.html", status: :not_found, layout: false
    end
  end

  private

  def set_time_zone
    if current_user && current_user.time_zone.present?
      Time.use_zone(current_user.time_zone) { yield }
    else
      yield
    end
  end
end
