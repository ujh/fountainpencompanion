module Bench
  module Suggester
    class BaselineSuggester < PenAndInkSuggester
      def initialize(user, instruction, rejected_pairs, as_of:, tier: nil, seed: nil, legacy: false)
        super(user, instruction, rejected_pairs, enforce_daily_limit: false, seed:)
        self.as_of = as_of
        self.tier = tier
        self.legacy = legacy
      end

      private

      attr_accessor :as_of, :tier, :legacy

      def v2?
        !legacy && super
      end

      def snapshot
        @snapshot ||= PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:)
      end

      def premium?
        tier ? tier == "premium" : super
      end

      def slice_tier
        tier ? tier.to_sym : super
      end
    end
  end
end
