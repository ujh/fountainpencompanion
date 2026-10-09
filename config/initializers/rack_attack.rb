# Throttle API requests. Two complementary rules:
#
# - Per-IP throttle on every /api/* request, so rotating bearer tokens
#   (or sending garbage tokens) cannot evade the throttle by handing
#   each request a fresh bucket key. This catches CPU-amplified DoS
#   that forces a bcrypt-compare on every garbage token.
# - Per-token throttle so a single legitimate user with a valid token
#   still hits a per-token ceiling regardless of source IP. Keyed on a
#   digest of the full token value, so only someone holding the secret
#   lands in a user's bucket.

def fpc_api_token_key(request)
  auth = request.env["HTTP_AUTHORIZATION"].to_s
  return nil if auth.empty?

  # Token-authenticator format: `Token token="<id>.<secret>"` (or with
  # the `Bearer` scheme, or no scheme at all).
  raw = auth[/token=("?)([^"\s,]+)\1/i, 2] || auth.sub(/\ABearer\s+/i, "").strip
  Digest::SHA256.hexdigest(raw) if raw.present?
end

Rack::Attack.throttle("api/ip", limit: 60, period: 60.seconds) do |request|
  request.ip if request.path.starts_with?("/api/")
end

Rack::Attack.throttle("api/token", limit: 15, period: 30.seconds) do |request|
  fpc_api_token_key(request) if request.path.starts_with?("/api/")
end

# Brute-force / credential-stuffing protection on Devise endpoints.
# Throttle sign-in / sign-up / password-reset by both IP and submitted email so
# that distributed attacks against a single account and noisy single-IP attacks
# are both blunted. Mail-sending endpoints (magic link, email change,
# confirmation resend) get tighter hourly limits on top.

def fpc_devise_user_params(request)
  user = request.params["user"]
  user.is_a?(Hash) ? user : {}
end

def fpc_devise_email(request)
  fpc_devise_user_params(request)["email"].to_s.downcase.strip.presence
end

Rack::Attack.throttle("logins/ip", limit: 5, period: 20.seconds) do |request|
  request.ip if request.post? && request.path == "/users/sign_in"
end

Rack::Attack.throttle("logins/email", limit: 5, period: 60.seconds) do |request|
  fpc_devise_email(request) if request.post? && request.path == "/users/sign_in"
end

Rack::Attack.throttle("logins/email/hour", limit: 20, period: 1.hour) do |request|
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

def fpc_magic_link_request?(request)
  request.post? && request.path == "/users/sign_in" &&
    fpc_devise_user_params(request)["password"].blank?
end

Rack::Attack.throttle("magic_link/ip", limit: 10, period: 1.hour) do |request|
  request.ip if fpc_magic_link_request?(request)
end

Rack::Attack.throttle("magic_link/email", limit: 3, period: 1.hour) do |request|
  fpc_devise_email(request) if fpc_magic_link_request?(request)
end

def fpc_email_change_request?(request)
  (request.put? || request.patch?) && request.path == "/users"
end

Rack::Attack.throttle("email_change/ip", limit: 3, period: 1.hour) do |request|
  request.ip if fpc_email_change_request?(request)
end

Rack::Attack.throttle("email_change/email", limit: 3, period: 1.hour) do |request|
  fpc_devise_email(request) if fpc_email_change_request?(request)
end

Rack::Attack.throttle("confirmation/ip", limit: 5, period: 1.hour) do |request|
  request.ip if request.post? && request.path == "/users/confirmation"
end

Rack::Attack.throttle("confirmation/email", limit: 3, period: 1.hour) do |request|
  fpc_devise_email(request) if request.post? && request.path == "/users/confirmation"
end

def fpc_search_query?(request)
  request.params["q"].present?
end

Rack::Attack.throttle("full text search limit", limit: 1, period: 3) do |request|
  request.ip if request.path.starts_with?("/inks") && fpc_search_query?(request)
end

Rack::Attack.throttle("pen model search limit", limit: 1, period: 3) do |request|
  request.ip if request.path.starts_with?("/pen_models") && fpc_search_query?(request)
end

Rack::Attack.throttle("ink review submissions/ip", limit: 20, period: 60) do |request|
  if request.post? &&
       request.path.match?(%r{\A/brands/[^/]+/inks/[^/]+/ink_review_submissions(\.json)?\z})
    request.ip
  end
end

def fpc_pen_and_ink_suggestion_enqueue?(request)
  fpc_pen_and_ink_suggestion_path?(request) && !fpc_pen_and_ink_suggestion_poll?(request)
end

def fpc_pen_and_ink_suggestion_path?(request)
  path = ActionDispatch::Journey::Router::Utils.normalize_path(request.path)
  match = path.b.match(%r{\A/dashboard/widgets/([^/.?]+)(?:\.[^/.?]+)?\z})
  match.present? && Rack::Utils.unescape_path(match[1]) == "pen_and_ink_suggestion"
end

def fpc_pen_and_ink_suggestion_poll?(request)
  id = request.GET["suggestion_id"]
  id.is_a?(String) && id.valid_encoding? && id.present?
rescue Rack::BadRequest
  false
end

Rack::Attack.throttle("pen and ink suggestions/ip", limit: 10, period: 60) do |request|
  request.ip if fpc_pen_and_ink_suggestion_enqueue?(request)
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

Rack::Attack.throttle("csp reports/ip", limit: 30, period: 60) do |request|
  request.ip if request.post? && request.path == "/csp-reports"
end
