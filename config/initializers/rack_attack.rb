# Throttle API requests. Two complementary rules:
#
# - Per-IP throttle on every /api/* request, so rotating bearer tokens
#   (or sending garbage tokens) cannot evade the throttle by handing
#   each request a fresh bucket key. This catches CPU-amplified DoS
#   that forces a bcrypt-compare on every garbage token.
# - Per-token-id throttle so a single legitimate user with a valid
#   token still hits a per-token ceiling regardless of source IP. Keyed
#   on the *id* portion of the token (everything before the first
#   ".") rather than the full Authorization header, because the secret
#   half is high-entropy and attackers could rotate it freely.

def fpc_api_token_id(request)
  auth = request.env["HTTP_AUTHORIZATION"].to_s
  return nil if auth.empty?

  # Token-authenticator format: `Token token="<id>.<secret>"` (or with
  # the `Bearer` scheme, or no scheme at all). Pull out the value, then
  # take the id half.
  raw = auth[/token=("?)([^"\s,]+)\1/i, 2] || auth.sub(/\ABearer\s+/i, "").strip
  id, _secret = raw.to_s.split(".", 2)
  id.presence
end

Rack::Attack.throttle("api/ip", limit: 60, period: 60.seconds) do |request|
  request.ip if request.path.starts_with?("/api/")
end

Rack::Attack.throttle("api/token-id", limit: 15, period: 30.seconds) do |request|
  fpc_api_token_id(request) if request.path.starts_with?("/api/")
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
