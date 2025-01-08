class UserAgent < ApplicationRecord
  BROWSERS = [
    "Chrome Mobile WebView",
    "Chrome Mobile iOS",
    "Chrome Mobile",
    "Chrome",
    "Consul Health Check",
    "Edge",
    "Firefox Mobile",
    "Firefox",
    "Mobile Safari",
    "Opera",
    "Safari"
  ].freeze

  scope :non_browser, -> { where.not(name: BROWSERS) }
end
