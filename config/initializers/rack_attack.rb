Rack::Attack.throttle("inks limit", limit: 5, period: 2) do |request|
  if request.path.starts_with?("/brands") || request.path.starts_with?("/inks")
    request.ip
  end
end
