require "csv"

module Bots
  class Base
    def self.env_name
      "OPEN_AI_#{name.demodulize.underscore.upcase}"
    end

    def run
      raise NotImplementedError
    end

    private

    def prompt
      raise NotImplementedError
    end

    def response_message
      @response_message ||=
        begin
          response =
            client.chat(
              parameters: {
                model: "gpt-4o-mini",
                messages: [{ role: "user", content: prompt }]
              }
            )
          response.dig("choices", 0, "message", "content")
        end
    end

    def client
      OpenAI::Client.new(access_token:, log_errors: !Rails.env.production?)
    end

    def access_token
      if Rails.env.development?
        ENV.fetch(self.class.env_name, ENV.fetch("OPEN_AI_DEV_TOKEN", nil))
      else
        ENV.fetch(self.class.env_name)
      end
    end
  end
end
