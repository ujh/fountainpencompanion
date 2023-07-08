# Higher limit, to avoid having the dashboard with it's many requests rate limited
Rack::Attack.throttle("general rate limit", limit: 10, period: 5) do |request|
  request.ip
end
