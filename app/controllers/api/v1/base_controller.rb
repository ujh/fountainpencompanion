class Api::V1::BaseController < ApplicationController
  include ActionController::HttpAuthentication::Token::ControllerMethods

  skip_forgery_protection if: :token_authentication?

  rescue_from ActionController::InvalidAuthenticityToken, with: :render_csrf_error
  rescue_from Apipie::ParamError, with: :render_param_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  before_action :require_json
  before_action :authenticate_via_token_or_session!

  private

  def require_json
    respond_to :json
  end

  def authenticate_via_token_or_session!
    if request.authorization.present?
      authenticate_with_token || render_unauthorized
    else
      authenticate_user!
    end
  end

  def authenticate_with_token
    authenticate_with_http_token do |access_token, _options|
      id, token = access_token.split(".", 2)
      return false if id.blank? || token.blank?

      auth_token = AuthenticationToken.authenticate_by(id: id, token: token)
      if auth_token
        auth_token.touch_last_used!
        request.env["devise.skip_trackable"] = true
        request.session_options[:skip] = true
        sign_in(auth_token.user, store: false)
        true
      else
        false
      end
    end
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def token_authentication?
    request.authorization.present?
  end

  def render_param_error(exception)
    render json: { errors: [{ detail: exception.message }] }, status: :bad_request
  end

  def render_not_found
    render json: { errors: [{ status: "404", title: "Not Found" }] }, status: :not_found
  end

  def page_size
    size = params.dig(:page, :size).to_i
    size if size.positive?
  end
end
