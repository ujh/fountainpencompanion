# frozen_string_literal: true

class CustomSessionsController < Devise::SessionsController
  def create
    super and return if create_params[:password].present?

    normalized_email = create_params[:email].to_s.strip.downcase.presence
    resource = normalized_email && resource_class.find_by(email: normalized_email)
    resource&.send_magic_link(remember_me: create_params[:remember_me])
    set_flash_message(:notice, :magic_link_sent_paranoid, now: true)

    self.resource = resource_class.new(create_params)
    render :new
  end

  protected

  def translation_scope
    if action_name == "create"
      "devise.passwordless"
    else
      super
    end
  end

  private

  def create_params
    resource_params.permit(:email, :password, :remember_me)
  end
end
