# frozen_string_literal: true

class CustomSessionsController < Devise::SessionsController
  def create
    super and return if create_params[:password].present?

    self.resource = resource_class.find_by(email: create_params[:email])
    if self.resource
      resource.send_magic_link(remember_me: create_params[:remember_me])
      set_flash_message(:notice, :magic_link_sent, now: true)
    else
      set_flash_message(:alert, :not_found_in_database, now: true)
    end

    redirect_to(
      after_magic_link_sent_path_for(resource),
      status: devise_redirect_status
    )
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
