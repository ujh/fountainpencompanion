module Bench
  module Suggester
    class ExtractorLabel
      KEYS = %w[text constraints reviewed notes split source ambiguous previous_suggestion].freeze

      attr_accessor :text,
                    :constraints,
                    :reviewed,
                    :notes,
                    :split,
                    :source,
                    :ambiguous,
                    :previous_suggestion

      def self.normalise_text(text)
        text.to_s.downcase.squish
      end

      def self.from_h(hash, index: 0)
        hash = (hash || {}).to_h.deep_stringify_keys
        context = "extractor label #{index}"
        unknown = hash.keys - KEYS
        if unknown.any?
          raise ConstraintSchema::Invalid, "#{context}: unknown keys #{unknown.join(", ")}"
        end
        raise ConstraintSchema::Invalid, "#{context}: text is blank" if hash["text"].to_s.blank?

        constraints =
          ConstraintSchema.normalise(hash["constraints"], context: "#{context}.constraints")
        if ConstraintSchema::SIDES.keys.any? { |side| constraints.dig(side, "exclude_ids") }
          raise ConstraintSchema::Invalid,
                "#{context}: exclude_ids is bench-only, the extractor names items by text"
        end

        new(
          text: hash["text"],
          constraints:,
          reviewed: hash["reviewed"] == true,
          notes: hash["notes"].to_s,
          split: hash["split"].to_s,
          source: hash["source"].to_s,
          ambiguous: hash["ambiguous"] == true,
          previous_suggestion: hash["previous_suggestion"] == true
        )
      end

      def self.load_file(path)
        return [] unless File.exist?(path)

        labels =
          Array(YAML.safe_load_file(path)).each_with_index.map do |hash, index|
            from_h(hash, index:)
          end
        duplicates =
          labels
            .group_by { |label| normalise_text(label.text) }
            .select { |_, group| group.size > 1 }
        if duplicates.any?
          raise ConstraintSchema::Invalid,
                "extractor labels: #{duplicates.size} texts are labelled more than once"
        end

        labels
      end

      def self.from_cases(cases, labels)
        cases
          .select(&:instruction?)
          .filter_map do |bench_case|
            label = labels[bench_case.id]
            next unless label

            constraints =
              label.constraints.to_h do |key, value|
                value.is_a?(Hash) ? [key, value.except("exclude_ids")] : [key, value]
              end
            new(
              text: bench_case.instruction.first(WidgetsController::MAX_EXTRA_USER_INPUT_LENGTH),
              constraints:,
              reviewed: label.reviewed?,
              notes: label.notes,
              split: bench_case.split,
              source: "p6",
              ambiguous: label.ambiguous?,
              previous_suggestion: bench_case.rejected_pairs.any?
            )
          end
          .uniq { |label| normalise_text(label.text) }
      end

      def initialize(
        text:,
        constraints:,
        reviewed:,
        notes:,
        split: "",
        source: "",
        ambiguous: false,
        previous_suggestion: false
      )
        self.text = text
        self.constraints = constraints
        self.reviewed = reviewed
        self.notes = notes
        self.split = split
        self.source = source
        self.ambiguous = ambiguous
        self.previous_suggestion = previous_suggestion
      end

      def reviewed? = reviewed

      def ambiguous? = ambiguous

      def to_h
        {
          "text" => text,
          "constraints" => constraints,
          "reviewed" => reviewed,
          "notes" => notes,
          "split" => split,
          "source" => source,
          "ambiguous" => ambiguous,
          "previous_suggestion" => previous_suggestion
        }
      end
    end
  end
end
