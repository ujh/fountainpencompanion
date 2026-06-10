# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # hCaptcha is checked BEFORE Devise builds the resource. On failure we
  # render the form with a base error and never call super, so no User
  # row is persisted. Previously the controller persisted a "bot"-flagged
  # row on failed captchas; that left the unique email index occupied
  # and let an attacker squat any victim's address without ever solving
  # a captcha (audit finding M-9).
  def create
    unless hcaptcha_passed?
      self.resource = resource_class.new(sign_up_params)
      resource.errors.add(:base, I18n.t("devise.failure.failed_captcha"))
      clean_up_passwords resource
      respond_with(resource) and return
    end

    super do |resource|
      resource.update(
        sign_up_user_agent: request.headers["User-Agent"],
        sign_up_ip: request.remote_ip
      )
    end
  end

  private

  def hcaptcha_passed?
    return false if params["h-captcha-response"].blank?

    response =
      hcaptcha_connection.post("/siteverify") do |req|
        req.body = {
          secret: ENV["HCAPTCHA_SECRET"],
          response: params["h-captcha-response"],
          remoteip: request.remote_ip
        }
      end

    response.body.is_a?(Hash) && response.body["success"] == true
  rescue Faraday::Error, JSON::ParserError
    # Fail closed — if hCaptcha is unreachable or returns garbage we
    # treat it as a failed challenge rather than silently letting the
    # registration through.
    false
  end

  def hcaptcha_connection
    Faraday.new("https://api.hcaptcha.com/") do |c|
      c.request :url_encoded
      c.response :json
      c.options.open_timeout = 5
      c.options.timeout = 10
    end
  end
end
