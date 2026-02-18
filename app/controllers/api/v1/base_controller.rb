class Api::V1::BaseController < ApplicationController
  include ActionController::HttpAuthentication::Token::ControllerMethods

  skip_forgery_protection if: :token_authentication?

  rescue_from ActionController::InvalidAuthenticityToken, with: :render_csrf_error

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
        sign_in(auth_token.user)
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

  def render_csrf_error
    render json: {
             errors: [{ detail: "CSRF token verification failed" }]
           },
           status: :unprocessable_entity
  end
end
