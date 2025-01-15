class UserAgent < ApplicationRecord
  BROWSERS = [
    "Amazon Silk",
    "Apple Mail",
    "Avast Secure Browser",
    "Chrome Mobile WebView",
    "Chrome Mobile iOS",
    "Chrome Mobile",
    "Chrome",
    "Consul Health Check",
    "DuckDuckGo Mobile",
    "DuckDuckGo",
    "Ecosia iOS",
    "Edge Mobile",
    "Edge",
    "Facebook",
    "Firefox Mobile",
    "Firefox iOS",
    "Firefox",
    "IE",
    "Instagram",
    "Mobile Safari",
    "Opera Mobile",
    "Opera",
    "Safari",
    "Samsung Internet",
    "Vivaldi"
  ].freeze

  scope :non_browser, -> { where.not(name: BROWSERS) }
end
