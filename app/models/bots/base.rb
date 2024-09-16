require "chatgpt/client"
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
              [{ role: "user", content: prompt }],
              { model: "gpt-4o-mini" }
            )
          response.dig("choices", 0, "message", "content")
        end
    end

    def client
      ChatGPT::Client.new(ENV.fetch("OPENAI_PEN_AND_INK_SUGGESTIONS"))
    end
  end
end
