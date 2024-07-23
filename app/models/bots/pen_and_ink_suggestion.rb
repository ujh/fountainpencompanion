require "chatgpt/client"

module Bots
  class PenAndInkSuggestion
    def initialize(user)
      self.user = user
    end

    def run
      response =
        client.chat(
          [{ role: "user", content: prompt }],
          { model: "gpt-4o-mini" }
        )
      message = response.dig("choices", 0, "message", "content")
      ink = inks.find { |ink| message.include?(ink.short_name) }
      pen = pens.find { |pen| message.include?(pen.name) }

      { message:, ink:, pen: }
    end

    private

    attr_accessor :user

    def client
      ChatGPT::Client.new(ENV["OPENAI_PEN_AND_INK_SUGGESTIONS"])
    end

    def prompt
      <<~MESSAGE
        Given the following fountain pens:
        #{pen_data}

        Given the following inks:
        #{ink_data}

        Which combination should I use and why? Prefer items that have either never been used or a long time ago.
        Be brief and make only one suggestion. Use markdown syntax for highlighting, but no headings.
      MESSAGE
    end

    def pen_data
      pens
        .map do |pen|
          usage = pen.last_used_on
          last_usage =
            if usage
              "last used #{ActionController::Base.helpers.time_ago_in_words(usage)} ago"
            else
              "never used"
            end
          # Quotes around the pen name to for the AI to spit out the full name, so that it can be found again.
          "#{pen.name.inspect} (last used #{last_usage})"
        end
        .join("\n")
    end

    def ink_data
      inks
        .map do |ink|
          usage = ink.last_used_on
          last_usage =
            if usage
              "last used #{ActionController::Base.helpers.time_ago_in_words(usage)} ago"
            else
              "never used"
            end
          "#{ink.short_name.inspect} (#{last_usage})"
        end
        .join("\n")
    end

    def pens
      @pens ||=
        user.collected_pens.active.includes(newest_currently_inked: :last_usage)
    end

    def inks
      @inks ||=
        user.collected_inks.active.includes(newest_currently_inked: :last_usage)
    end
  end
end
