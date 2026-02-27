class AccountDeletionsController < ApplicationController
  before_action :authenticate_user!

  def create
    UserMailer.account_deletion_confirmation(current_user).deliver_later
    redirect_to account_path,
                notice: "We've sent you an email with a link to confirm your account deletion."
  end

  def show
    user = User.find_signed(params[:token], purpose: :account_deletion)
    if user == current_user
      @token = params[:token]
    else
      redirect_to account_path, alert: "Invalid or expired link."
    end
  end

  def destroy
    user = User.find_signed(params[:token], purpose: :account_deletion)
    if user == current_user
      user.update!(deletion_requested_at: Time.current)
      CleanUp::DeleteUser.perform_async(user.id)
      sign_out(user)
      redirect_to root_path, notice: "Your account has been scheduled for deletion."
    else
      redirect_to account_path, alert: "Invalid or expired link."
    end
  end
end
