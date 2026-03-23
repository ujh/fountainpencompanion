module ConfigureToken
  extend ActiveSupport::Concern

  class_methods do
    def token_name
      "OPEN_AI_#{self.name.underscore.upcase}_TOKEN"
    end
  end

  included { configure { |config| config.max_tool_calls = 50 } }

  # Temporarily swap the global RubyLLM API key for this agent's key.
  # Restores the default key afterward to avoid leaking into other threads.
  def chat_completion(**kwargs)
    original_key = RubyLLM.config.openai_api_key
    RubyLLM.config.openai_api_key = access_token
    super
  ensure
    RubyLLM.config.openai_api_key = original_key
  end

  private

  def access_token
    if Rails.env.development?
      ENV.fetch("OPEN_AI_DEV_TOKEN", nil)
    else
      ENV.fetch(self.class.token_name, ENV.fetch("OPEN_AI_TOKEN", nil))
    end
  end
end
