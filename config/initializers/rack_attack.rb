# Throttle API requests by authorization token
Rack::Attack.throttle("api requests", limit: 15, period: 30) do |request|
  request.env["HTTP_AUTHORIZATION"] if request.env["HTTP_AUTHORIZATION"].present?
end

# Brute-force / credential-stuffing protection on Devise endpoints.
# Throttle sign-in / sign-up / password-reset by both IP and submitted email so
# that distributed attacks against a single account and noisy single-IP attacks
# are both blunted. Magic-link sends are covered by the sign-in throttles since
# they share the same endpoint.

def fpc_devise_email(request)
  request.params.dig("user", "email").to_s.downcase.strip.presence
end

Rack::Attack.throttle("logins/ip", limit: 5, period: 20.seconds) do |request|
  request.ip if request.post? && request.path == "/users/sign_in"
end

Rack::Attack.throttle("logins/email", limit: 5, period: 60.seconds) do |request|
  fpc_devise_email(request) if request.post? && request.path == "/users/sign_in"
end

Rack::Attack.throttle("password_reset/ip", limit: 5, period: 1.hour) do |request|
  request.ip if request.post? && request.path == "/users/password"
end

Rack::Attack.throttle("password_reset/email", limit: 3, period: 1.hour) do |request|
  fpc_devise_email(request) if request.post? && request.path == "/users/password"
end

Rack::Attack.throttle("signups/ip", limit: 5, period: 1.hour) do |request|
  request.ip if request.post? && request.path == "/users"
end

Rack::Attack.throttle("full text search limit", limit: 1, period: 3) do |request|
  request.ip if request.path.starts_with?("/inks") && request.query_string.include?("q=")
end

Rack::Attack.throttle("missing descriptions", limit: 10, period: 20) do |request|
  request.ip if request.path.starts_with?("/descriptions/missing")
end

Rack::Attack.throttle("crawler", limit: 1, period: 120) do |request|
  "crawler" if request.user_agent =~ /Googlebot/i
end

# Avoid peaks when posting to Mastodon
Rack::Attack.throttle("Mastodon", limit: 1, period: 1) do |request|
  "mastodon" if request.user_agent =~ /mastodon/i
end

# General bot throttling
Rack::Attack.throttle("bots", limit: 1, period: 1) do |request|
  request.user_agent if request.user_agent =~ /bot|scrapy/i
end

# Block misbehaving bots
# See https://social.treehouse.systems/@dee/112524729369220652
Rack::Attack.blocklist("Misbehaving bots") do |request|
  request.user_agent =~
    /AhrefsBot|Baiduspider|SemrushBot|SeekportBot|BLEXBot|Buck|magpie-crawler|ZoominfoBot|HeadlessChrome|istellabot|Sogou|coccocbot|Pinterestbot|moatbot|Mediatoolkitbot|SeznamBot|trendictionbot|MJ12bot|DotBot|PetalBot|YandexBot|bingbot|ClaudeBot|imagesift|GPTBot|Bytespider|Timpibot|meta-externalagent|facebook|Amazonbot|Applebot|AliyunSecBot|DataForSeoBot|serpstatbot|ccbot|crawler|panscient/i
end
