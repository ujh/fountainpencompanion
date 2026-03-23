RubyLLM.configure do |config|
  config.openai_api_key =
    Rails.env.development? ? ENV.fetch("OPEN_AI_DEV_TOKEN", nil) : ENV.fetch("OPEN_AI_TOKEN", nil)
end

Raix.configure { |config| config.max_tool_calls = 50 }
