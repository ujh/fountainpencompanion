class ApplicationMailer < ActionMailer::Base
  default from: "hello@mail.fountainpencompanion.com", reply_to: "hello@fountainpencompanion.com"
  layout "mailer"
end
