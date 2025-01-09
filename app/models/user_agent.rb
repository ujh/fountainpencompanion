class UserAgent < ApplicationRecord
  BROWSERS = [
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
    "Edge",
    "Firefox Mobile",
    "Firefox iOS",
    "Firefox",
    "IE",
    "Instagram",
    "Mobile Safari",
    "Opera",
    "Safari",
    "Samsung Internet"
  ].freeze

  scope :non_browser, -> { where.not(name: BROWSERS) }
end
