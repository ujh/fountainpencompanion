Rack::Attack.throttle(
  "full text search limit",
  limit: 1,
  period: 3
) do |request|
  if request.path.starts_with?("/inks") && request.query_string.include?("q=")
    request.ip
  end
end

Rack::Attack.throttle(
  "missing descriptions",
  limit: 10,
  period: 20
) { |request| request.ip if request.path.starts_with?("/descriptions/missing") }

Rack::Attack.throttle("crawler", limit: 1, period: 60) do |request|
  "crawler" if request.user_agent =~ /crawler|Googlebot|ccbot/i
end

# Avoid peaks when posting to Mastodon
Rack::Attack.throttle("Mastodon", limit: 1, period: 1) do |request|
  "mastodon" if request.user_agent =~ /mastodon/i
end

# Blocklist for misbehaving clients. The IP gets banned for 1 hour after 120 requests in 1 minute.
Rack::Attack.blocklist("blocklist for misbehaving clients v2") do |request|
  Rack::Attack::Allow2Ban.filter(
    request.ip,
    maxretry: 120,
    findtime: 1.minute,
    bantime: 1.hour
  ) do
    !(
      request.path.starts_with?("/admins") ||
        request.path.starts_with?("/assets")
    )
  end
end

# Block misbehaving bots
# See https://social.treehouse.systems/@dee/112524729369220652
Rack::Attack.blocklist("Misbehaving bots") do |request|
  request.user_agent =~
    /AhrefsBot|Baiduspider|SemrushBot|SeekportBot|BLEXBot|Buck|magpie-crawler|ZoominfoBot|HeadlessChrome|istellabot|Sogou|coccocbot|Pinterestbot|moatbot|Mediatoolkitbot|SeznamBot|trendictionbot|MJ12bot|DotBot|PetalBot|YandexBot|bingbot|ClaudeBot|imagesift|GPTBot|Bytespider|Timpibot|meta-externalagent|facebook|Amazonbot|Applebot|AliyunSecBot|DataForSeoBot|serpstatbot/i
end
