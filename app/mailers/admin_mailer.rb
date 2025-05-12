class AdminMailer < ApplicationMailer
  def agent_mail(subject, body)
    @body = body
    mail(to: "hello@fountainpencompanion.com", subject: subject)
  end
end
