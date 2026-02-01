access_token =
  Rails.env.development? ? ENV.fetch("OPEN_AI_DEV_TOKEN", nil) : ENV.fetch("OPEN_AI_TOKEN", nil)

Raix.configure do |config|
  config.max_tool_calls = 50
  config.openai_client =
    if ENV["USE_OLLAMA"] == "true"
      # Ollama's OpenAI-compatible endpoint is at /v1/chat/completions
      # We set uri_base to just the host:port and let the client add /v1/chat/completions
      OpenAI::Client.new(uri_base: "http://ollama:11434/v1", request_timeout: 240) do |f|
        f.response :logger, Logger.new($stdout), bodies: true if Rails.env.development?
      end
    else
      OpenAI::Client.new(access_token:) do |f|
        f.response :logger, Logger.new($stdout), bodies: true if Rails.env.development?
      end
    end
end
