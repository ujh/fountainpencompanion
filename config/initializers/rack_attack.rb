Rack::Attack.throttle("inks limit", limit: 3, period: 1) do |request|
  if request.path.starts_with?("/brands") || request.path.starts_with?("/inks")
    request.ip
  end
end
