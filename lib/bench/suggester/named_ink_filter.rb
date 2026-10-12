module Bench
  module Suggester
    class NamedInkFilter
      PLACEHOLDER = "the"

      def call(run)
        user = User.find_by(id: run.user_id)
        return false unless user

        snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user, as_of: run.created_at)
        ink_ids(snapshot, run.instruction).any?
      end

      def ink_ids(snapshot, instruction)
        text = instruction.to_s.first(WidgetsController::MAX_EXTRA_USER_INPUT_LENGTH)
        index = PenAndInkSuggestion::NameIndex.for(snapshot)
        (matched(snapshot, index, text) + ruled_out(index, text)).uniq
      end

      private

      def matched(snapshot, index, text)
        mentions = PenAndInkSuggestion::MentionMatcher.call(index, without_negations(text))
        PenAndInkSuggestion::NameResolver.call(snapshot, mentions, index:).ink_pins.map(&:id)
      end

      def without_negations(text)
        PenAndInkSuggestion::NameText
          .tokens(text)
          .reverse
          .each_with_object(text.dup) do |token, rewritten|
            rewritten[token.start...token.stop] = PLACEHOLDER if negation?(token.text)
          end
      end

      def ruled_out(index, text)
        words = PenAndInkSuggestion::NameText.words(text)
        index.entries.filter_map do |entry|
          name = entry.fields[:name]
          next if entry.side != :ink || name.none? { |word| vocabulary.evidence?(word) }

          negated =
            words
              .each_cons(name.size + 1)
              .any? { |negation, *rest| negation?(negation) && rest == name }
          entry.item.id if negated
        end
      end

      def negation?(word) = vocabulary.negation?(word)

      def vocabulary = PenAndInkSuggestion::MentionVocabulary
    end
  end
end
