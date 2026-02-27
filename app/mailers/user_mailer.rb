class UserMailer < ApplicationMailer
  def account_deletion_confirmation(user)
    @user = user
    @token = user.signed_id(purpose: :account_deletion, expires_in: 24.hours)
    @url = account_deletion_url(token: @token)
    mail(to: user.email, subject: "Confirm your account deletion")
  end
end
