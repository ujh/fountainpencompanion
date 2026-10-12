module Bench
  module Suggester
    class ExtractorScore
      HARD_FIELDS = %w[
        keep_from_previous
        pair_usage
        pen.mentions
        pen.exclude_mentions
        pen.comment_exclude
        pen.nib_grades_include
        pen.nib_grades_exclude
        pen.nib_width
        pen.nib_characters_include
        pen.nib_characters_exclude
        pen.usage
        ink.mentions
        ink.exclude_mentions
        ink.tags_exclude
        ink.kinds_include
        ink.kinds_exclude
        ink.colour_include
        ink.colour_exclude
        ink.shimmer
        ink.scented
        ink.usage
      ].freeze
      SOFT_FIELDS = %w[out_of_scope requested_count pen.sort ink.sort].freeze
      FIELDS = (HARD_FIELDS + SOFT_FIELDS).freeze
      TERM_FIELDS = %w[mentions exclude_mentions comment_exclude tags_exclude].freeze
      GATE = 0.03
      SIDES = %i[pen ink].freeze

      attr_accessor :labels, :predictions

      def initialize(labels:, predictions:)
        self.labels = labels
        self.predictions = predictions
      end

      def rows
        @rows ||=
          labels.filter_map do |label|
            prediction = predictions[label.text]
            next unless prediction

            row(label, prediction)
          end
      end

      def summary
        totals(rows).merge(
          "gate" => GATE,
          "by_split" =>
            rows
              .group_by { |row| row["split"] }
              .sort
              .to_h
              .transform_values { |split_rows| totals(split_rows) },
          "reviewed" => totals(rows.select { |row| row["reviewed"] })
        )
      end

      private

      def row(label, prediction)
        expected = PenAndInkSuggestion::Constraints.from_h(label.constraints)
        actual = PenAndInkSuggestion::Constraints.from_h(prediction.fetch("constraints", {}))
        fields = FIELDS.index_with { |path| compare(path, expected, actual) }
        scored = !label.ambiguous? && !prediction["error"]
        hard_false_positives = scored ? HARD_FIELDS.select { |path| fields[path][:fp].any? } : []
        named_sides = %w[pen ink].select { |side| expected.mentions(side.to_sym).any? }
        named = SIDES.flat_map { |side| expected.mentions(side) }
        mentioned = SIDES.flat_map { |side| actual.mentions(side) }
        {
          "text" => label.text,
          "split" => label.split,
          "source" => label.source,
          "reviewed" => label.reviewed?,
          "ambiguous" => label.ambiguous?,
          "error" => prediction["error"],
          "scored" => scored,
          "fields" => fields.transform_values { |counts| counts.transform_keys(&:to_s) },
          "hard_false_positives" => hard_false_positives,
          "hard_false_positives_off_named_sides" =>
            hard_false_positives.reject { |path| on_named_side?(path, named_sides) },
          "soft_notes" => actual.soft_notes.present?,
          "named_mentions" => named,
          "missed_named_mentions" =>
            named.reject { |want| mentioned.any? { |term| same_term?(term, want) } }
        }
      end

      def compare(path, expected, actual)
        name = path.split(".").last
        wanted = items(path, expected)
        got = items(path, actual)
        if TERM_FIELDS.include?(name)
          matched = got.select { |term| wanted.any? { |want| same_term?(term, want) } }
          missed = wanted.reject { |want| got.any? { |term| same_term?(term, want) } }
          { tp: matched, fp: got - matched, fn: missed }
        else
          { tp: got & wanted, fp: got - wanted, fn: wanted - got }
        end
      end

      def items(path, constraints)
        value = constraints.value(path)
        return Array(value) if value.is_a?(Array)
        return [] if constraints.default?(path)

        [value.to_s]
      end

      def on_named_side?(path, named_sides)
        side, name = path.split(".")
        name.present? && name != "mentions" && named_sides.include?(side)
      end

      def same_term?(term, want)
        term_words = words(term)
        want_words = words(want)
        return false if term_words.empty? || want_words.empty?

        covered?(term_words, want_words) || covered?(want_words, term_words)
      end

      def covered?(shorter, longer)
        shorter.all? do |word|
          longer.any? do |other|
            PenAndInkSuggestion::NameText.same_word?(word, other) ||
              (word.length >= 4 && other.start_with?(word)) ||
              (other.length >= 4 && word.start_with?(other))
          end
        end
      end

      def words(text)
        PenAndInkSuggestion::NameText.words(text).uniq
      end

      def totals(selected)
        scored = selected.select { |row| row["scored"] }
        with_false_positive = scored.count { |row| row["hard_false_positives"].any? }
        without_mentions =
          scored.count { |row| (row["hard_false_positives"] - %w[pen.mentions ink.mentions]).any? }
        off_named_sides = scored.count { |row| row["hard_false_positives_off_named_sides"].any? }
        named = scored.select { |row| row["named_mentions"].any? }
        missed = named.count { |row| row["missed_named_mentions"].any? }
        {
          "strings" => selected.size,
          "errors" => selected.count { |row| row["error"] },
          "scored" => scored.size,
          "with_hard_false_positive" => with_false_positive,
          "hard_false_positive_rate" => rate(with_false_positive, scored.size),
          "with_hard_false_positive_outside_mentions" => without_mentions,
          "hard_false_positive_rate_outside_mentions" => rate(without_mentions, scored.size),
          "with_hard_false_positive_off_named_sides" => off_named_sides,
          "hard_false_positive_rate_off_named_sides" => rate(off_named_sides, scored.size),
          "with_named_mention" => named.size,
          "with_missed_named_mention" => missed,
          "missed_named_mention_rate" => rate(missed, named.size),
          "soft_notes_share" => rate(selected.count { |row| row["soft_notes"] }, selected.size),
          "fields" => FIELDS.index_with { |path| field_totals(scored, path) }
        }
      end

      def field_totals(scored, path)
        tp, fp, fn = %w[tp fp fn].map { |kind| scored.sum { |row| row["fields"][path][kind].size } }
        {
          "tp" => tp,
          "fp" => fp,
          "fn" => fn,
          "precision" => rate(tp, tp + fp),
          "recall" => rate(tp, tp + fn)
        }
      end

      def rate(count, total)
        total.zero? ? nil : (count.to_f / total).round(4)
      end
    end
  end
end
