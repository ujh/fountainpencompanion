# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |resource|
      resource.update(
        sign_up_user_agent: request.headers["User-Agent"],
        sign_up_ip: request.remote_ip
      )
    end
  end

  private

  def sign_up_params
    data = super
    check_captcha!(data)
    data
  end

  def check_captcha!(data)
    conn =
      Faraday.new("https://api.hcaptcha.com/") do |c|
        c.request :url_encoded
        c.response :json
      end
    response =
      conn.post("/siteverify") do |req|
        req.body = { secret: ENV["HCAPTCHA_SECRET"], response: params["h-captcha-response"] }
      end

    return if response.body["success"]
    data["bot"] = true
    data["bot_reason"] = "failed-captcha(#{response.body["error-codes"].join(",")})"
  end
end
