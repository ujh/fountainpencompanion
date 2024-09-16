module Bots
  class PenAndInkSuggestion < Bots::Base
    LIMIT = 50

    def initialize(user)
      self.user = user
    end

    def run
      remaining_tries = 5
      suggestion = request_suggestion

      loop do
        remaining_tries -= 1
        break if remaining_tries.zero?
        break if suggestion[:ink] && suggestion[:pen]

        Rails.logger.debug("Retrying, as either ink or pen not found")
        # Sometimes it picks two inks. In that case we want to try
        # once more. But only once, as we don't want and endless
        # loop that also costs us money.
        suggestion = request_suggestion
      end

      suggestion
    end

    private

    attr_accessor :user

    def request_suggestion
      ink = inks.find { |ink| response_message.include?(ink.name) }
      ink ||= inks.find { |ink| response_message.include?(ink.short_name) }
      pen = pens.find { |pen| response_message.include?(pen.name) }

      { message: response_message, ink: ink&.id, pen: pen&.id }
    end

    def prompt
      <<~MESSAGE
        Given the following fountain pens:
        #{pen_data}

        Given the following inks:
        #{ink_data}

        Which combination of ink and fountain pen should I use and why?

        Prefer items that have either never been used, rarely used, or used a long time ago.
        Also suggest items that have been used a lot.
        Make only one suggestion.
        Use markdown syntax for highlighting.
        Do not mention usage and daily usage count if they are zero.
        Use the ink tags and description as part of the reasoning, but do not mention them directly.
      MESSAGE
    end

    def pen_data
      CSV.generate do |csv|
        csv << [
          "fountain pen name",
          "last usage",
          "usage count",
          "daily usage count"
        ]
        pens
          .shuffle
          .take(LIMIT)
          .each do |pen|
            last_usage =
              if pen.last_used_on
                ActionController::Base.helpers.time_ago_in_words(
                  pen.last_used_on
                )
              else
                "never"
              end
            csv << [
              pen.name.inspect,
              last_usage,
              pen.usage_count,
              pen.daily_usage_count
            ]
          end
      end
    end

    def ink_data
      CSV.generate do |csv|
        csv << [
          "ink name",
          "last usage",
          "usage count",
          "daily usage count",
          "tags",
          "description"
        ]

        inks
          .shuffle
          .take(LIMIT)
          .each do |ink|
            last_usage =
              if ink.last_used_on
                ActionController::Base.helpers.time_ago_in_words(
                  ink.last_used_on
                )
              else
                "never"
              end
            csv << [
              ink.name.inspect,
              last_usage,
              ink.usage_count,
              ink.daily_usage_count,
              ink.cluster_tags.join(","),
              ink.cluster_description
            ]
          end
      end
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
          micro_cluster: {
            macro_cluster: :brand_cluster
          },
          newest_currently_inked: :last_usage
        )
    end
  end
end
