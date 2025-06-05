access_token =
  Rails.env.development? ? ENV.fetch("OPEN_AI_DEV_TOKEN", nil) : ENV.fetch("OPEN_AI_TOKEN", nil)

Raix.configure do |config|
  config.max_tool_calls = 50
  config.openai_client =
    OpenAI::Client.new(access_token:) do |f|
      f.response :logger, Logger.new($stdout), bodies: true if Rails.env.development?
    end
end
