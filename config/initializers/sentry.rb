# frozen_string_literal: true

Sentry.init do |config|
  config.breadcrumbs_logger = [:active_support_logger]
  config.dsn = ENV["SENTRY_DSN"]
  config.enable_tracing = true
  config.enabled_patches << :faraday

  config.excluded_exceptions +=
    YAML.load_file(Rails.root.join("config", "honeybadger.yml")).dig(
      "exceptions",
      "ignore"
    )
end
