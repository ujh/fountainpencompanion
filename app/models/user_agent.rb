class UserAgent < ApplicationRecord
  BROWSERS = [
    "Avast Secure Browser",
    "Chrome Mobile WebView",
    "Chrome Mobile iOS",
    "Chrome Mobile",
    "Chrome",
    "Consul Health Check",
    "Ecosia iOS",
    "Edge",
    "Firefox Mobile",
    "Firefox iOS",
    "Firefox",
    "Instagram",
    "Mobile Safari",
    "Opera",
    "Safari",
    "Samsung Internet"
  ].freeze

  scope :non_browser, -> { where.not(name: BROWSERS) }
end
