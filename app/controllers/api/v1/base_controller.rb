class Api::V1::BaseController < ApplicationController
  before_action :require_json
  before_action :authenticate_user!

  private

  def require_json
    respond_to :json
  end
end
