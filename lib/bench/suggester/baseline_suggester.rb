module Bench
  module Suggester
    class BaselineSuggester < PenAndInkSuggester
      def initialize(user, instruction, rejected_pairs, as_of:, tier: nil)
        super(user, instruction, rejected_pairs, enforce_daily_limit: false)
        self.as_of = as_of
        self.tier = tier
      end

      private

      attr_accessor :as_of, :tier

      def snapshot
        @snapshot ||= PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:)
      end

      def premium?
        tier ? tier == "premium" : super
      end
    end
  end
end
