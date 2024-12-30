class AdminMailer < ApplicationMailer
  def new_cluster(new_clusters)
    mail(
      to: "hello@fountainpencompanion.com",
      subject: "#{new_clusters} new cluster to assign!"
    )
  end
end
