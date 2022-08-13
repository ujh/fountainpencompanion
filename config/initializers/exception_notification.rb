require 'exception_notification/rails'

require 'exception_notification/sidekiq'


ignore_list = [
  "ActionController::InvalidAuthenticityToken",
  "ActionDispatch::Http::MimeNegotiation::InvalidType",
  "ActionDispatch::Http::Parameters::ParseError"
]

# Goes here for the Sidekiq emails
ExceptionNotification.configure do |config|
  config.ignore_if {|exception, options| not Rails.env.production? }
  config.ignored_exceptions = ignore_list
  config.error_grouping = true
  config.error_grouping_cache = Rails.cache
  config.add_notifier :email, {
    :email_prefix => "[FPC] ",
    :sender_address => %{"Exception Notifier" <exception-notifier@fountainpencompanion.com>},
    :exception_recipients => %w{contact@urbanhafner.com}
  }
end
