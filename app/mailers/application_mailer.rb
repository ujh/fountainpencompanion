class ApplicationMailer < ActionMailer::Base
  default from: "hello@mail.fountainpencompanion.com", reply_to: "hello@foutainpencompanion.com"
  layout "mailer"
end
