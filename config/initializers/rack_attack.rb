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
