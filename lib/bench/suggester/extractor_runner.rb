module Bench
  module Suggester
    class ExtractorRunner
      BUDGET = "budget"
      UNPRICED = "unpriced"

      attr_accessor :labels,
                    :max_usd,
                    :model,
                    :reasoning_effort,
                    :names_found,
                    :spent_usd,
                    :stop_reason

      def initialize(labels:, max_usd: 5.0, model: nil, reasoning_effort: nil, names_found: true)
        self.labels = labels
        self.max_usd = max_usd
        self.model = model
        self.reasoning_effort = reasoning_effort
        self.names_found = names_found
        self.spent_usd = 0.0
      end

      def model_settings
        ModelSettings.new(model, reasoning_effort:) if model
      end

      def run
        results = {}
        labels.each do |label|
          if spent_usd >= max_usd
            self.stop_reason = BUDGET
            break
          end

          result = extract(label)
          results[label.text] = result
          yield label, result if block_given?
          if result["cost_usd"].nil?
            self.stop_reason = UNPRICED
            break
          end

          self.spent_usd += result["cost_usd"]
        end
        results
      end

      private

      def extractor_class
        @extractor_class ||=
          if model
            settings = model_settings
            settings.register!
            Class.new(PenAndInkConstraintExtractor) do
              define_singleton_method(:name) { PenAndInkConstraintExtractor.name }
              define_method(:model_id) { settings.model_id }
              define_method(:temperature) { super() if settings.temperature? }
              define_method(:reasoning_effort) { settings.reasoning_effort }
              private :model_id, :temperature, :reasoning_effort
            end
          else
            PenAndInkConstraintExtractor
          end
      end

      def found_names(label)
        return [] unless names_found && label.context?

        user = users.fetch(label.user_id) { users[label.user_id] = User.find_by(id: label.user_id) }
        return [] unless user

        snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user, as_of: label.as_of)
        index = PenAndInkSuggestion::NameIndex.for(snapshot)
        mentions = PenAndInkSuggestion::MentionMatcher.call(index, label.text)
        PenAndInkSuggestion::NameHints.call(snapshot, mentions, index:)
      end

      def users
        @users ||= {}
      end

      def extract(label)
        result = nil
        lines = found_names(label)
        ActiveRecord::Base.transaction(requires_new: true) do
          parent = AgentLog.create!(name: PenAndInkSuggester.name, transcript: [])
          extractor =
            extractor_class.new(
              label.text,
              parent_agent_log: parent,
              previous_suggestion: label.previous_suggestion,
              names_found: lines
            )
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          constraints = extractor.perform
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
          usage = extractor.agent_log.reload.usage
          result = {
            "constraints" => constraints&.to_h,
            "error" => extractor.error,
            "names_found" => lines,
            "usage" => usage,
            "cost_usd" => Pricing.cost(usage),
            "list_cost_usd" => Pricing.cost(usage, cache_discount: false),
            "latency_ms" => latency_ms
          }
          raise ActiveRecord::Rollback
        end
        result
      end
    end
  end
end
