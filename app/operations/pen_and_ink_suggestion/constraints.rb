class PenAndInkSuggestion::Constraints
  GRADES = %w[EF F MF M B BB].freeze
  NIB_WIDTHS = %w[any fine broadish broad].freeze
  NIB_CHARACTERS = %w[stub italic oblique fude flex architect music zoom naginata].freeze
  KINDS = %w[bottle sample cartridge].freeze
  COLOURS = ColorProfile::FAMILIES
  USAGES = %w[any never_used used_before].freeze
  SORTS = %w[default least_recent most_used].freeze
  TRISTATE = %w[any include exclude].freeze
  PAIR_USAGES = %w[any new repeat].freeze
  KEEP_FROM_PREVIOUS = %w[none pen ink].freeze

  MAX_TERM_LENGTH = 60
  MAX_SOFT_NOTES_LENGTH = 300
  MAX_REQUESTED_COUNT = 10

  Field = Data.define(:type, :default, :values, :limit)

  def self.enum(values) = Field.new(type: :enum, default: values.first, values:, limit: nil)
  def self.enum_list(values) = Field.new(type: :enum_list, default: [], values:, limit: nil)
  def self.terms(limit) = Field.new(type: :terms, default: [], values: nil, limit:)

  TOP_FIELDS = {
    out_of_scope: Field.new(type: :boolean, default: false, values: nil, limit: nil),
    requested_count: Field.new(type: :count, default: 1, values: nil, limit: MAX_REQUESTED_COUNT),
    keep_from_previous: enum(KEEP_FROM_PREVIOUS),
    pair_usage: enum(PAIR_USAGES),
    soft_notes: Field.new(type: :text, default: "", values: nil, limit: MAX_SOFT_NOTES_LENGTH)
  }.freeze

  SIDE_FIELDS = {
    pen: {
      mentions: terms(5),
      exclude_mentions: terms(10),
      comment_exclude: terms(3),
      nib_grades_include: enum_list(GRADES),
      nib_grades_exclude: enum_list(GRADES),
      nib_width: enum(NIB_WIDTHS),
      nib_characters_include: enum_list(NIB_CHARACTERS),
      nib_characters_exclude: enum_list(NIB_CHARACTERS),
      usage: enum(USAGES),
      sort: enum(SORTS)
    },
    ink: {
      mentions: terms(5),
      exclude_mentions: terms(10),
      tags_exclude: terms(5),
      kinds_include: enum_list(KINDS),
      kinds_exclude: enum_list(KINDS),
      colour_include: enum_list(COLOURS),
      colour_exclude: enum_list(COLOURS),
      shimmer: enum(TRISTATE),
      scented: enum(TRISTATE),
      usage: enum(USAGES),
      sort: enum(SORTS)
    }
  }.freeze

  EXCLUSIONS = {
    pen: %i[exclude_mentions comment_exclude nib_grades_exclude nib_characters_exclude],
    ink: %i[exclude_mentions tags_exclude kinds_exclude colour_exclude shimmer scented]
  }.freeze
  INCLUSIONS = {
    pen: %i[nib_grades_include nib_width nib_characters_include usage],
    ink: %i[kinds_include colour_include shimmer usage]
  }.freeze

  attr_reader :values, :nib_width_slack

  def self.empty
    new
  end

  def self.from_h(hash)
    hash = (hash.respond_to?(:to_h) ? hash.to_h : {}).deep_symbolize_keys
    values =
      TOP_FIELDS
        .to_h { |name, field| [name, validate(hash[name], field)] }
        .merge(
          SIDE_FIELDS.to_h do |side, fields|
            side_hash = hash[side].is_a?(Hash) ? hash[side] : {}
            [side, fields.to_h { |name, field| [name, validate(side_hash[name], field)] }]
          end
        )
    new(values)
  end

  def self.validate(value, field)
    case field.type
    when :boolean
      value == true
    when :count
      count = value.is_a?(String) ? Integer(value.strip, exception: false) : value
      count.is_a?(Integer) && count.positive? ? [count, field.limit].min : field.default
    when :text
      value.is_a?(String) ? value.squish.truncate(field.limit, omission: "") : field.default
    when :terms
      Array
        .wrap(value)
        .grep(String)
        .map { |term| term.squish.truncate(MAX_TERM_LENGTH, omission: "") }
        .compact_blank
        .uniq(&:downcase)
        .first(field.limit)
    when :enum
      enum_value(value, field) || field.default
    when :enum_list
      Array.wrap(value).filter_map { |item| enum_value(item, field) }.uniq
    end
  end

  def self.enum_value(value, field)
    return unless value.is_a?(String)

    field.values.find { |allowed| allowed.casecmp?(value.strip) }
  end

  def self.default_values
    TOP_FIELDS.transform_values(&:default).merge(
      SIDE_FIELDS.transform_values { |fields| fields.transform_values(&:default) }
    )
  end

  private_class_method :validate, :enum_value

  def initialize(values = self.class.default_values, nib_width_slack: 0)
    self.values = deep_freeze(values.deep_dup)
    self.nib_width_slack = nib_width_slack
  end

  def value(path)
    side, name = split(path)
    side ? values.fetch(side).fetch(name) : values.fetch(name)
  end

  def default?(path)
    value(path) == field(path).default
  end

  def with(path, new_value, nib_width_slack: self.nib_width_slack)
    side, name = split(path)
    updated = values.deep_dup
    side ? updated[side][name] = new_value : updated[name] = new_value
    self.class.new(updated, nib_width_slack:)
  end

  def reset(path)
    slack = path.to_s == "pen.nib_width" ? 0 : nib_width_slack
    with(path, field(path).default, nib_width_slack: slack)
  end

  def exclusions(side)
    active_filters(side, EXCLUSIONS.fetch(side), "exclude")
  end

  def inclusions(side)
    active_filters(side, INCLUSIONS.fetch(side), "include")
  end

  def filters?(side = nil)
    sides = side ? [side] : SIDE_FIELDS.keys
    sides.any? { |each_side| (exclusions(each_side) + inclusions(each_side)).any? } ||
      (side.nil? && !default?(:pair_usage))
  end

  def mentions(side)
    value("#{side}.mentions")
  end

  def to_h
    hash = values.deep_stringify_keys
    hash["pen"]["nib_width_slack"] = nib_width_slack if nib_width_slack.positive?
    hash
  end

  def ==(other)
    other.is_a?(self.class) && other.values == values && other.nib_width_slack == nib_width_slack
  end

  alias eql? ==

  def hash
    [values, nib_width_slack].hash
  end

  TOP_FIELDS.each_key { |name| define_method(name) { values.fetch(name) } }

  private

  attr_writer :values, :nib_width_slack

  def deep_freeze(value)
    case value
    when Hash
      value.each_value { |item| deep_freeze(item) }
    when Array
      value.each { |item| deep_freeze(item) }
    end
    value.freeze
  end

  def active_filters(side, names, tristate_mode)
    names.filter_map do |name|
      path = "#{side}.#{name}"
      next if default?(path)
      next if field(path).values == TRISTATE && value(path) != tristate_mode

      path
    end
  end

  def field(path)
    side, name = split(path)
    side ? SIDE_FIELDS.fetch(side).fetch(name) : TOP_FIELDS.fetch(name)
  end

  def split(path)
    parts = path.to_s.split(".").map(&:to_sym)
    parts.size == 2 ? parts : [nil, parts.first]
  end
end
