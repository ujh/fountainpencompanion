class AdminMailer < ApplicationMailer
  def new_cluster
    mail(
      to: "hello@fountainpencompanion.com",
      subject: "New cluster to assign! "
    )
  end
end
