module Bench
  module Suggester
    class ExtractorLabel
      KEYS = %w[text constraints reviewed notes].freeze

      attr_accessor :text, :constraints, :reviewed, :notes

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
          notes: hash["notes"].to_s
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

      def initialize(text:, constraints:, reviewed:, notes:)
        self.text = text
        self.constraints = constraints
        self.reviewed = reviewed
        self.notes = notes
      end

      def reviewed? = reviewed
    end
  end
end
