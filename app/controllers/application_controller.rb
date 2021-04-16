class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  protect_from_forgery with: :exception
  around_action :set_time_zone

  if !Rails.env.development?
    rescue_from ActionView::MissingTemplate do |exception|
      render file: "public/404.html", status: :not_found, layout: false
    end
  end

  def after_sign_in_path_for(resource)
    if resource.admin?
      admins_dashboard_path
    else
      dashboard_path
    end
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:bot_field])
  end

  def set_time_zone
    if current_user && current_user.time_zone.present?
      Time.use_zone(current_user.time_zone) { yield }
    else
      yield
    end
  end
end
