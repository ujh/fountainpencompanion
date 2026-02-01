module ConfigureToken
  extend ActiveSupport::Concern

  class_methods do
    def token_name
      "OPEN_AI_#{self.name.underscore.upcase}_TOKEN"
    end
  end

  included do
    configure do |config|
      access_token =
        (
          if Rails.env.development?
            ENV.fetch("OPEN_AI_DEV_TOKEN", nil)
          else
            ENV.fetch(token_name, "OPEN_AI_TOKEN")
          end
        )

      config.max_tool_calls = 50
      config.openai_client =
        if ENV["USE_OLLAMA"] == "true"
          OpenAI::Client.new(uri_base: "http://ollama:11434/v1", request_timeout: 240) do |f|
            f.response :logger, Logger.new($stdout), bodies: true if Rails.env.development?
          end
        else
          OpenAI::Client.new(access_token:) do |f|
            f.response :logger, Logger.new($stdout), bodies: true if Rails.env.development?
          end
        end
    end
  end
end
