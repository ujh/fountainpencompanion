class AdminMailer < ApplicationMailer
  def agent_mail(subject, body)
    @body = body
    mail(to: "hello@fountainpencompanion.com", subject: subject)
  end

  def patreon_badges_to_deliver(users)
    @users = users
    mail(
      to: "hello@fountainpencompanion.com",
      subject: "#{users.size} Patreon badge(s) to mark delivered"
    )
  end
end
