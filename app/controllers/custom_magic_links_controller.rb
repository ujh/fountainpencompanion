# frozen_string_literal: true

class CustomMagicLinksController < Devise::MagicLinksController
  skip_before_action :allow_params_authentication!, only: :show

  def show
    self.resource = authenticate_with_magic_link!
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    redirect_to after_sign_in_path_for(resource)
  end

  private

  def authenticate_with_magic_link!
    allow_params_authentication!
    warden.authenticate!(:magic_link_authenticatable, auth_options)
  ensure
    request.env.delete("devise.allow_params_authentication")
  end
end
