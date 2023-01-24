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
end
