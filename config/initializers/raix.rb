access_token =
  Rails.env.development? ? ENV.fetch("OPEN_AI_DEV_TOKEN", nil) : ENV.fetch("OPEN_AI_TOKEN", nil)

Raix.configure { |config| config.openai_client = OpenAI::Client.new(access_token:) }
