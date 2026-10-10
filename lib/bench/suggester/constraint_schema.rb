module Bench
  module Suggester
    module ConstraintSchema
      class Invalid < StandardError
      end

      GRADES = %w[EF F MF M B BB].freeze
      NIB_WIDTHS = %w[any fine broadish broad].freeze
      NIB_CHARACTERS = %w[stub italic oblique fude flex architect music zoom naginata].freeze
      KINDS = %w[bottle sample cartridge].freeze
      USAGES = %w[any never_used used_before].freeze
      SORTS = %w[default least_recent most_used].freeze
      TRISTATE = %w[any include exclude].freeze

      Field = Data.define(:type, :values)

      def self.enum(*values) = Field.new(type: :enum, values: values.flatten)
      def self.enum_list(*values) = Field.new(type: :enum_list, values: values.flatten)
      def self.of(type) = Field.new(type:, values: nil)

      TOP_FIELDS = {
        "out_of_scope" => of(:boolean),
        "requested_count" => of(:integer),
        "keep_from_previous" => enum(%w[none pen ink]),
        "pair_usage" => enum(%w[any new repeat]),
        "soft_notes" => of(:string)
      }.freeze

      PEN_FIELDS = {
        "mentions" => of(:strings),
        "exclude_mentions" => of(:strings),
        "exclude_ids" => of(:ids),
        "comment_exclude" => of(:strings),
        "nib_grades_include" => enum_list(GRADES),
        "nib_grades_exclude" => enum_list(GRADES),
        "nib_width" => enum(NIB_WIDTHS),
        "nib_characters_include" => enum_list(NIB_CHARACTERS),
        "nib_characters_exclude" => enum_list(NIB_CHARACTERS),
        "usage" => enum(USAGES),
        "sort" => enum(SORTS)
      }.freeze

      INK_FIELDS = {
        "mentions" => of(:strings),
        "exclude_mentions" => of(:strings),
        "exclude_ids" => of(:ids),
        "tags_exclude" => of(:strings),
        "kinds_include" => enum_list(KINDS),
        "kinds_exclude" => enum_list(KINDS),
        "colour_include" => enum_list(ColorProfile::FAMILIES),
        "colour_exclude" => enum_list(ColorProfile::FAMILIES),
        "shimmer" => enum(TRISTATE),
        "scented" => enum(TRISTATE),
        "usage" => enum(USAGES),
        "sort" => enum(SORTS)
      }.freeze

      SIDES = { "pen" => PEN_FIELDS, "ink" => INK_FIELDS }.freeze

      def self.normalise(constraints, context: "constraints")
        constraints = (constraints || {}).to_h.deep_stringify_keys
        unknown = constraints.keys - TOP_FIELDS.keys - SIDES.keys
        raise Invalid, "#{context}: unknown fields #{unknown.join(", ")}" if unknown.any?

        normalised = normalise_fields(constraints.slice(*TOP_FIELDS.keys), TOP_FIELDS, context)
        SIDES.each do |side, fields|
          next unless constraints.key?(side)

          values = constraints[side]
          raise Invalid, "#{context}.#{side}: must be a mapping" unless values.is_a?(Hash)

          unknown = values.keys - fields.keys
          raise Invalid, "#{context}.#{side}: unknown fields #{unknown.join(", ")}" if unknown.any?

          normalised[side] = normalise_fields(values, fields, "#{context}.#{side}")
        end
        normalised
      end

      def self.normalise_fields(values, fields, context)
        values.to_h do |name, value|
          [name, normalise_value(value, fields.fetch(name), "#{context}.#{name}")]
        end
      end

      def self.normalise_value(value, field, path)
        case field.type
        when :boolean
          return value if [true, false].include?(value)
        when :integer
          return value if value.is_a?(Integer) && value.positive?
        when :string
          return value.to_s if value.is_a?(String)
        when :strings
          return value.map(&:to_s) if value.is_a?(Array) && value.all?(String)
        when :ids
          return value if value.is_a?(Array) && value.all?(Integer)
        when :enum
          return enum_value(value, field) if value.is_a?(String) && enum_value(value, field)
        when :enum_list
          if value.is_a?(Array) &&
               value.all? { |item| item.is_a?(String) && enum_value(item, field) }
            return value.map { |item| enum_value(item, field) }
          end
        end
        raise Invalid, "#{path}: invalid value #{value.inspect}"
      end

      def self.enum_value(value, field)
        field.values.find { |allowed| allowed.casecmp?(value.strip) }
      end

      private_class_method :normalise_fields, :normalise_value, :enum_value
    end
  end
end
