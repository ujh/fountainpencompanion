module ConfigureToken
  extend ActiveSupport::Concern

  included do
    configure do |config|
      token_name = "OPEN_AI_#{self.name.underscore.upcase}_TOKEN"
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
        OpenAI::Client.new(access_token:) do |f|
          f.response :logger, Logger.new($stdout), bodies: true if Rails.env.development?
        end
    end
  end
end
