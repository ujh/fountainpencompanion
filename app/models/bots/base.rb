require "csv"

module Bots
  class Base
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
      OpenAI::Client.new(
        access_token: ENV.fetch("OPENAI_PEN_AND_INK_SUGGESTIONS"),
        log_errors: !Rails.env.production?
      )
    end
  end
end
