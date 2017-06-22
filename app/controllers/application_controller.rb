class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  rescue_from ActionView::MissingTemplate do |exception|
    render file: "public/404.html", status: :not_found, layout: false
  end

  def after_sign_in_path_for(resource)
    if resource.admin?
      admins_users_path
    else
      collected_inks_path
    end
  end
end
