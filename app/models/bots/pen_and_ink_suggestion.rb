require "chatgpt/client"

module Bots
  class PenAndInkSuggestion
    def initialize(user)
      self.user = user
    end

    def run
      suggestion = request_suggestion

      if suggestion[:ink] && suggestion[:pen]
        suggestion
      else
        # Sometimes it picks two inks. In that case we want to try
        # once more. But only once, as we don't want and endless
        # loop that also costs us money.
        request_suggestion
      end
    end

    private

    attr_accessor :user

    def request_suggestion
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

    def client
      ChatGPT::Client.new(ENV["OPENAI_PEN_AND_INK_SUGGESTIONS"])
    end

    def prompt
      <<~MESSAGE
        Given the following fountain pens:
        #{pen_data}

        Given the following inks:
        #{ink_data}

        Which combination should I use and why?

        Prefer items that have either never been used or a long time ago.
        Sometimes also suggest items that have been used a lot.
        Make only one suggestion. Use markdown syntax for highlighting.
      MESSAGE
    end

    def pen_data
      pens
        .map do |pen|
          last_usage = pen.last_used_on
          usage_count = pen.usage_count + pen.daily_usage_count
          usage =
            if last_usage
              "last usage of #{usage_count} total uses #{ActionController::Base.helpers.time_ago_in_words(last_usage)} ago"
            else
              "never used"
            end
          # Quotes around the pen name to for the AI to spit out the full name, so that it can be found again.
          "#{pen.name.inspect} (#{usage})"
        end
        .shuffle
        .join("\n")
    end

    def ink_data
      inks
        .map do |ink|
          last_usage = ink.last_used_on
          usage_count = ink.usage_count + ink.daily_usage_count
          usage =
            if last_usage
              "last usage of #{usage_count} total uses #{ActionController::Base.helpers.time_ago_in_words(last_usage)} ago"
            else
              "never used"
            end
          "#{ink.short_name.inspect} (#{usage})"
        end
        .shuffle
        .join("\n")
    end

    def pens
      @pens ||=
        user
          .collected_pens
          .active
          .includes(
            :currently_inkeds,
            :usage_records,
            newest_currently_inked: :last_usage
          )
          .reject { |pen| pen.inked? }
    end

    def inks
      @inks ||=
        user.collected_inks.active.includes(
          :currently_inkeds,
          :usage_records,
          newest_currently_inked: :last_usage
        )
    end
  end
end
