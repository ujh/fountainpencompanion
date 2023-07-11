Rack::Attack.throttle(
  "full text search limit",
  limit: 1,
  period: 3
) do |request|
  if request.path.starts_with?("/inks") && request.query_string.include?("q=")
    request.ip
  end
end
