module Bench
  module Suggester
    class ExtractorRunner
      BUDGET = "budget"
      UNPRICED = "unpriced"

      attr_accessor :labels, :max_usd, :model, :spent_usd, :stop_reason

      def initialize(labels:, max_usd: 5.0, model: nil)
        self.labels = labels
        self.max_usd = max_usd
        self.model = model
        self.spent_usd = 0.0
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
            override = model
            Class.new(PenAndInkConstraintExtractor) do
              define_singleton_method(:name) { PenAndInkConstraintExtractor.name }
              define_method(:model_id) { override }
              private :model_id
            end
          else
            PenAndInkConstraintExtractor
          end
      end

      def extract(label)
        result = nil
        ActiveRecord::Base.transaction(requires_new: true) do
          parent = AgentLog.create!(name: PenAndInkSuggester.name, transcript: [])
          extractor =
            extractor_class.new(
              label.text,
              parent_agent_log: parent,
              previous_suggestion: label.previous_suggestion
            )
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          constraints = extractor.perform
          latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
          usage = extractor.agent_log.reload.usage
          result = {
            "constraints" => constraints&.to_h,
            "error" => extractor.error,
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
