module Bench
  module Suggester
    class MentionPins
      GATE = 0.02

      attr_accessor :cases, :labels

      def initialize(cases:, labels:)
        self.cases = cases
        self.labels = labels
      end

      def rows
        @rows ||= cases.filter_map { |bench_case| row(bench_case) }
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

      def totals(selected)
        {
          "strings" => selected.size,
          "pinned" => selected.count { |row| row["pins"].any? },
          "with_false_pin" => with_false_pin(selected),
          "false_pin_rate" => rate(with_false_pin(selected), selected.size),
          "pins" => selected.sum { |row| row["pins"].size },
          "false_pins" => selected.sum { |row| row["false_pins"].size },
          "named" => named(selected).size,
          "named_hit" => named(selected).count { |row| row["hit"] },
          "named_hit_rate" =>
            rate(named(selected).count { |row| row["hit"] }, named(selected).size),
          "notes" => selected.sum { |row| row["notes"].size }
        }
      end

      def row(bench_case)
        label = labels[bench_case.id]
        return unless bench_case.instruction? && label

        user = User.find_by(id: bench_case.user_id)
        return unless user

        resolution = resolve(bench_case, user)
        named =
          label.named_pens.map { |id| ["pen", id] } + label.named_inks.map { |id| ["ink", id] }
        pins =
          resolution.pen_pins.map { |pen| ["pen", pen.id] } +
            resolution.ink_pins.map { |ink| ["ink", ink.id] }
        {
          "case_id" => bench_case.id,
          "split" => bench_case.split,
          "reviewed" => label.reviewed,
          "pins" => pins,
          "false_pins" => pins - named,
          "named" => named.any?,
          "hit" => (pins & named).any?,
          "notes" => resolution.notes
        }
      end

      def resolve(bench_case, user)
        snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user, as_of: bench_case.as_of)
        index = PenAndInkSuggestion::NameIndex.for(snapshot)
        instruction = bench_case.instruction.first(WidgetsController::MAX_EXTRA_USER_INPUT_LENGTH)
        mentions = PenAndInkSuggestion::MentionMatcher.call(index, instruction)
        PenAndInkSuggestion::NameResolver.call(snapshot, mentions, index:)
      end

      def with_false_pin(selected)
        selected.count { |row| row["false_pins"].any? }
      end

      def named(selected)
        selected.select { |row| row["named"] }
      end

      def rate(count, total)
        total.zero? ? nil : (count.to_f / total).round(4)
      end
    end
  end
end
