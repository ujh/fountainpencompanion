class AuthenticationTokensController < ApplicationController
  before_action :authenticate_user!
  before_action :set_token, only: %i[update destroy]

  def index
    @tokens = current_user.authentication_tokens.order(created_at: :desc)
    @new_token = AuthenticationToken.new
  end

  def create
    @token = current_user.authentication_tokens.build(token_params)
    if @token.save
      flash[:new_access_token] = @token.access_token
      redirect_to authentication_tokens_path, notice: "API token created successfully."
    else
      @tokens = current_user.authentication_tokens.order(created_at: :desc)
      @new_token = @token
      render :index
    end
  end

  def update
    if @token.update(token_params)
      redirect_to authentication_tokens_path, notice: "API token updated."
    else
      @tokens = current_user.authentication_tokens.order(created_at: :desc)
      @new_token = AuthenticationToken.new
      render :index
    end
  end

  def destroy
    @token.destroy
    redirect_to authentication_tokens_path, notice: "API token deleted."
  end

  private

  def set_token
    @token = current_user.authentication_tokens.find(params[:id])
  end

  def token_params
    params.require(:authentication_token).permit(:name)
  end
end
