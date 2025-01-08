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

Rack::Attack.throttle("Google", limit: 1, period: 1) do |request|
  "Google" if request.user_agent =~ /Googlebot/i
end

Rack::Attack.throttle("crawler", limit: 1, period: 1) do |request|
  "crawler" if request.user_agent =~ /crawler/i
end

Rack::Attack.throttle("Amazonbot", limit: 1, period: 10) do |request|
  "Amazonbot" if request.user_agent =~ /Amazonbot/i
end

# See https://social.treehouse.systems/@dee/112524729369220652
Rack::Attack.blocklist("Misbehaving bots") do |request|
  request.user_agent =~
    /AhrefsBot|Baiduspider|SemrushBot|SeekportBot|BLEXBot|Buck|magpie-crawler|ZoominfoBot|HeadlessChrome|istellabot|Sogou|coccocbot|Pinterestbot|moatbot|Mediatoolkitbot|SeznamBot|trendictionbot|MJ12bot|DotBot|PetalBot|YandexBot|bingbot|ClaudeBot|imagesift|GPTBot|Bytespider|Timpibot|meta-externalagent/i
end
