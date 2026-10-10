require "csv"

module Bench
  module Suggester
    class LoggedRun
      INSTRUCTION_MARKER = "IMPORTANT: Take extra care to follow these additional instructions:\n"
      REJECTED_MARKER =
        "\n\nThe following suggestions were rejected. Do not recommend them again:\n"
      PENS_MARKER = "Given the following fountain pens:\n"
      INKS_MARKER = "Given the following inks:\n"
      INKS_END_MARKERS = [
        "\n\nInks have the following average statistics:",
        "\n\nWhich combination"
      ].freeze
      MAX_REJECTED_PAIRS = 50

      attr_accessor :agent_log

      def initialize(agent_log)
        self.agent_log = agent_log
      end

      def log_id = agent_log.id

      def user_id = agent_log.owner_id

      def created_at = agent_log.created_at

      def llm_run?
        prompt.present? && !precheck?
      end

      def precheck?
        extra_data.key?("precheck")
      end

      def prompt
        @prompt ||= initial_user_messages.join("\n\n")
      end

      def instruction
        return @instruction if defined?(@instruction)

        start = prompt.index(INSTRUCTION_MARKER)
        @instruction =
          if start
            finish = rejected_start && rejected_start > start ? rejected_start : prompt.length
            prompt[(start + INSTRUCTION_MARKER.length)...finish].strip.presence
          end
      end

      def normalised_instruction
        ExtractorLabel.normalise_text(instruction)
      end

      def rejected_pairs
        @rejected_pairs ||=
          if rejected_start
            Array(rejected_json)
              .filter_map do |entry|
                next unless entry.is_a?(Hash)

                ink_id = integer(entry["ink_id"])
                pen_id = integer(entry["pen_id"])
                { "ink_id" => ink_id, "pen_id" => pen_id } if ink_id && pen_id
              end
              .last(MAX_REJECTED_PAIRS)
          else
            []
          end
      end

      def shown_pen_ids
        csv_ids(section(PENS_MARKER, ["\n\n"]))
      end

      def shown_ink_ids
        csv_ids(section(INKS_MARKER, INKS_END_MARKERS))
      end

      def original
        {
          "pen_id" => extra_data["pen"],
          "ink_id" => extra_data["ink"],
          "message" => extra_data["message"],
          "model" => usage["model"],
          "prompt_tokens" => usage["prompt_tokens"],
          "completion_tokens" => usage["completion_tokens"]
        }
      end

      def tier
        model = usage["model"].to_s
        if model.start_with?("gpt-4.1-mini")
          "free"
        elsif model.start_with?("gpt-4.1")
          "premium"
        end
      end

      def extra_data
        (agent_log.extra_data || {}).stringify_keys
      end

      private

      def usage
        (agent_log.usage || {}).stringify_keys
      end

      def initial_user_messages
        Array(agent_log.transcript)
          .take_while do |entry|
            entry.is_a?(Hash) && !(entry.key?("assistant") || entry["role"].in?(%w[assistant tool]))
          end
          .filter_map { |entry| entry["role"] == "user" ? entry["content"] : entry["user"] }
          .map(&:to_s)
      end

      def rejected_start
        return @rejected_start if defined?(@rejected_start)

        start = prompt.rindex(REJECTED_MARKER)
        @rejected_start = start if start && rejected_json_at(start)
      end

      def rejected_json
        rejected_json_at(rejected_start)
      end

      def rejected_json_at(start)
        parsed = JSON.parse(prompt[(start + REJECTED_MARKER.length)..].strip)
        parsed if parsed.is_a?(Array)
      rescue JSON::ParserError
        nil
      end

      def integer(value)
        value if value.is_a?(Integer)
      end

      def section(marker, end_markers)
        start = prompt.index(marker)
        return unless start

        start += marker.length
        finish = end_markers.filter_map { |end_marker| prompt.index(end_marker, start) }.min
        prompt[start...(finish || prompt.length)]
      end

      def csv_ids(text)
        return unless text

        CSV.parse(text).filter_map { |row| row.first.to_i if row.first.to_s.match?(/\A\d+\z/) }
      rescue CSV::MalformedCSVError
        nil
      end
    end
  end
end
