module Bench
  module Suggester
    class Label
      CATEGORIES = %w[
        specific_pen
        colour
        ink_properties
        novelty_usage
        exclusions
        ink_kind
        specific_ink
        season_mood
        multiple_suggestions
        nib
        match_pen_colour
        relative_to_inked
        purpose
        pen_properties
        metadata
        household
        describes_pen
        feedback_previous
        collection_question
        shopping
        app_support
        prompt_injection
        non_english
        bare_names
      ].freeze

      KEYS = %w[categories named_pens named_inks constraints reviewed corrected notes].freeze

      attr_accessor :case_id,
                    :categories,
                    :named_pens,
                    :named_inks,
                    :constraints,
                    :reviewed,
                    :corrected,
                    :notes

      def self.from_h(case_id, hash)
        hash = (hash || {}).to_h.deep_stringify_keys
        context = "label #{case_id}"
        unknown = hash.keys - KEYS
        if unknown.any?
          raise ConstraintSchema::Invalid, "#{context}: unknown keys #{unknown.join(", ")}"
        end
        if hash["corrected"] == true && hash["reviewed"] != true
          raise ConstraintSchema::Invalid, "#{context}: corrected needs reviewed: true"
        end

        new(
          case_id: case_id.to_s,
          categories: categories(hash["categories"], context),
          named_pens: ids(hash["named_pens"], "#{context}.named_pens"),
          named_inks: ids(hash["named_inks"], "#{context}.named_inks"),
          constraints:
            ConstraintSchema.normalise(hash["constraints"], context: "#{context}.constraints"),
          reviewed: hash["reviewed"] == true,
          corrected: hash["corrected"] == true,
          notes: hash["notes"].to_s
        )
      end

      def self.load_file(path)
        return {} unless File.exist?(path)

        (YAML.safe_load_file(path) || {}).to_h do |case_id, hash|
          [case_id.to_s, from_h(case_id, hash)]
        end
      end

      def self.categories(values, context)
        values = Array(values)
        unknown = values - CATEGORIES
        if unknown.any?
          raise ConstraintSchema::Invalid, "#{context}: unknown categories #{unknown.join(", ")}"
        end

        values
      end

      def self.ids(values, context)
        values = Array(values)
        unless values.all?(Integer)
          raise ConstraintSchema::Invalid, "#{context}: ids must be integers"
        end

        values
      end

      private_class_method :categories, :ids

      def initialize(
        case_id:,
        categories:,
        named_pens:,
        named_inks:,
        constraints:,
        reviewed:,
        corrected:,
        notes:
      )
        self.case_id = case_id
        self.categories = categories
        self.named_pens = named_pens
        self.named_inks = named_inks
        self.constraints = constraints
        self.reviewed = reviewed
        self.corrected = corrected
        self.notes = notes
      end

      def reviewed? = reviewed

      def corrected? = corrected

      def to_h
        {
          "categories" => categories,
          "named_pens" => named_pens,
          "named_inks" => named_inks,
          "constraints" => constraints,
          "reviewed" => reviewed,
          "corrected" => corrected,
          "notes" => notes
        }
      end
    end
  end
end
