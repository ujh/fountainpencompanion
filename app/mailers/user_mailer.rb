class UserMailer < ApplicationMailer
  helper ErrorReportsHelper

  def account_deletion_confirmation(user)
    @user = user
    @token = user.signed_id(purpose: :account_deletion, expires_in: 24.hours)
    @url = account_deletion_url(token: @token)
    mail(to: user.email, subject: "Confirm your account deletion")
  end

  def error_report_reply(entry)
    @entry = entry
    @error_report = entry.error_report
    @user = @error_report.user
    mail(to: @user.email, subject: "About your report: #{@error_report.reportable_name}")
  end
end
