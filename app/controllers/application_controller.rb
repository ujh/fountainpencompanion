class ApplicationController < ActionController::Base
  include SearchQuery
  protect_from_forgery with: :exception
  around_action :set_time_zone

  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token

  unless Rails.env.development?
    rescue_from ActionView::MissingTemplate do |_exception|
      render file: "public/404.html", status: :not_found, layout: false
    end
  end

  private

  # JSON clients get a machine-readable error so they can refresh their token
  # (see CsrfTokensController) and retry. HTML requests keep the default behaviour.
  def handle_invalid_authenticity_token(exception)
    raise exception if request.format.html?

    render_csrf_error
  end

  def render_csrf_error
    render json: {
             errors: [{ code: "invalid_csrf_token", detail: "CSRF token verification failed" }]
           },
           status: :unprocessable_content
  end

  def set_time_zone(&)
    if current_user && current_user.time_zone.present?
      Time.use_zone(current_user.time_zone, &)
    else
      yield
    end
  end
end
