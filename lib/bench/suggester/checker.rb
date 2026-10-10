module Bench
  module Suggester
    class Checker
      attr_accessor :snapshot, :extra_data, :rejected_pairs, :label

      def initialize(snapshot:, extra_data:, rejected_pairs: [], label: nil)
        self.snapshot = snapshot
        self.extra_data = (extra_data || {}).to_h.stringify_keys
        self.rejected_pairs = rejected_pairs
        self.label = label
      end

      def call
        outcome = Checks::Outcome.call(extra_data)
        suggestion = outcome == Checks::Outcome::SUGGESTION
        {
          "outcome" => outcome,
          "hard_failure" => outcome == Checks::Outcome::ERROR,
          "validity" => (validity if suggestion),
          "leakage" => (Checks::RuleLeakage.for(extra_data).call if suggestion),
          "novelty" => (Checks::Novelty.new(snapshot:, extra_data:).call if suggestion),
          "named" => (Checks::NamedTargets.new(label:, extra_data:).call if label),
          "constraints" => (constraints if label)
        }
      end

      private

      def validity
        Checks::Validity.new(snapshot:, extra_data:, rejected_pairs:).call
      end

      def constraints
        Checks::Constraints.new(snapshot:, extra_data:, constraints: label.constraints).call
      end
    end
  end
end
