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
  "missing descriptions limit",
  limit: 2,
  period: 30
) { |request| request.ip if request.path.starts_with?("/descriptions/missing") }
