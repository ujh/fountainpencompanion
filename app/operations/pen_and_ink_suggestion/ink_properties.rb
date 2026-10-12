class PenAndInkSuggestion::InkProperties
  PROPERTIES = %i[
    shimmer
    sheen
    shading
    chameleon
    scented
    water_resistant
    pigmented
    iron_gall
  ].freeze

  NAME_PROPERTIES = %i[shimmer sheen scented water_resistant pigmented iron_gall].freeze

  LABELS = {
    shimmer: "shimmer",
    sheen: "sheen",
    shading: "shading",
    chameleon: "chameleon",
    scented: "scented",
    water_resistant: "water-resistant",
    pigmented: "pigmented",
    iron_gall: "iron gall"
  }.freeze

  PATTERNS = {
    shimmer: [
      /\bshimmer(?!ing)\w*/,
      /\bshimmering(?=\s+(?:inks?|particles)\b)/,
      /\bglitter\b/,
      /\bpearlescent\b/
    ],
    sheen: [/\bsheen\w*/],
    shading: [
      /\b(?:chrom[ao]?|multi|dual|duo)[\s-]?shad(?:e|es|ing|er|ers)\b/,
      /\bshad(?:ing|er|ers)\b/,
      /\bshades\s+(?:well|nicely|beautifully|a\s+lot|strongly|heavily)\b/
    ],
    chameleon: [/\bchameleon\b/, /\bcolou?r[\s-]?shift\w*/, /\bduo[\s-]?chrome\b/],
    scented: [
      /\bscented\b/,
      /\bperfumed\b/,
      /\bfragranced\b/,
      /\b(?:scent|fragrance)s?\b(?!\s+of\b)/
    ],
    water_resistant: [
      /\bwater[\s-]?(?:proof|resist\w*|fast\w*)/,
      /\bbullet[\s-]?proof\b/,
      /\barchival\b/,
      %r{\bpermanent\b(?=\s*(?:ink\b|and\b|or\b|[,.;/]|\z))}
    ],
    pigmented: [/\bpigmented\b/, /\bpigment\b(?=[\s-]*(?:ink|based|particles)\b)/],
    iron_gall: [/\biron[\s-]?gall\b/]
  }.freeze

  LABEL_PATTERNS = {
    shimmer: [/\bshimmering\b/, /\bglitter\w*/, /\bsparkl\w*/],
    water_resistant: [/\bpermanent\b(?![\s-]+(?:line|range|collection)\b)/],
    shading: [/\Ashade(?:\.\w+)?\z/],
    scented: [/\Asmell(?:s|y)?\z/],
    pigmented: [/\Apigments?\z/]
  }.freeze

  attr_accessor :properties

  def self.for(collected_ink)
    from_texts(
      tags: collected_ink.tags.map(&:name) + collected_ink.cluster_tags,
      names: [collected_ink.brand_name, collected_ink.line_name, collected_ink.ink_name],
      descriptions: [collected_ink.cluster_description]
    )
  end

  def self.from_texts(tags: [], names: [], descriptions: [])
    tags, names, descriptions =
      [tags, names, descriptions].map { |texts| Matcher.normalise_all(texts) }
    new(
      PROPERTIES.select do |property|
        matcher = Matcher.new(property)
        labels = NAME_PROPERTIES.include?(property) ? tags + names : tags
        labels.any? { |label| matcher.match?(label, label: true) } ||
          descriptions.any? { |description| matcher.match?(description) }
      end
    )
  end

  def initialize(properties = [])
    self.properties = PROPERTIES & Array(properties).map(&:to_sym)
  end

  PROPERTIES.each { |property| define_method(:"#{property}?") { include?(property) } }

  def include?(property)
    properties.include?(property.to_sym)
  end

  def none?
    properties.empty?
  end

  def labels
    properties.map { |property| LABELS.fetch(property) }
  end

  class Matcher
    NEGATIONS = %w[no not non un without never zero nor neither none lacks lacking free].freeze
    COMPARISONS = %w[like unlike than add].freeze
    WEAK_QUALIFIERS = %w[
      low
      little
      slight
      slightly
      some
      somewhat
      mild
      mildly
      partial
      partially
      semi
      minimal
      poor
      limited
      bit
      degree
    ].freeze
    WINDOW = 4
    HEDGED_PROPERTIES = %i[shading sheen].freeze
    HEDGES = %w[
      low
      little
      slight
      slightly
      some
      subtle
      subtly
      minimal
      minor
      faint
      faintly
      mild
      mildly
      limited
    ].freeze
    HEDGE_NOUNS = %w[smidge smidgen hint touch bit tad trace].freeze
    HEDGE_REACH = 2
    QUITE_A = %w[quite a].freeze
    NOT_BETWEEN_HEDGE = %w[
      nice
      good
      great
      lovely
      beautiful
      gorgeous
      amazing
      excellent
      wonderful
      stunning
      pretty
      heavy
      heavily
      strong
      intense
      extreme
      high
      rich
      lots
      plenty
      decent
      pronounced
      noticeable
      significant
      considerable
      dramatic
      the
      this
      that
      these
      those
      its
      their
      is
      are
      was
      has
      have
      shows
      papers
      paper
    ].freeze
    HEDGED_AFTER =
      /\A\s+(?:is|are|was|remains)\s+(?:(?:very|quite|rather|fairly|only|relatively)\s+)?(?:subtle|minimal|slight|faint|minor|limited|low|light|mild|weak)\b/
    SWATCH_ONLY =
      /\A(?:[\s-]+(?!(?:not|and|but|or)\b)[a-z'-]+){0,3}?\s+(?:in|on)\s+(?:(?:large|big|heavy|thick|wide|broad)\s+)?(?:swatch|swab)\w*/
    ALSO_IN_WRITING =
      /\A\s*,?\s*(?:and|but|as\s+well\s+as|or)\s+(?:also\s+)?(?:in\s+)?(?:writing|handwriting|text|lines?|nibs?)\b/
    CLAUSE_BOUNDARY = /[.!?;:,\n\r]|\b(?:and|but)\b/
    WORD = /[a-z']+/
    NEGATED_AFTER =
      /\A(?:[\s-]*free\b|\s*[-–—:=?]\s*(?:no|none)\b|\s+(?:version|edition|variant)s?\b)/
    LIST_TAIL = /,?\s*\b(?:and|or|nor)\b\s*\z|,\s*\z/
    TERM_AT_END = /(?:#{Regexp.union(PATTERNS.values.flatten).source})\z/

    def self.normalise_all(texts)
      Array(texts).map { |text| text.to_s.downcase.tr("’_#", "'  ").strip }.compact_blank
    end

    def initialize(property)
      self.property = property
      self.patterns = PATTERNS.fetch(property)
      self.label_patterns = patterns + LABEL_PATTERNS.fetch(property, [])
    end

    def match?(text, label: false)
      (label ? label_patterns : patterns).any? do |pattern|
        affirmed_match?(text, pattern, prose: !label)
      end
    end

    private

    attr_accessor :property, :patterns, :label_patterns

    def affirmed_match?(text, pattern, prose:)
      position = 0
      while (match = pattern.match(text, position))
        return true if affirmed?(text, match) && (!prose || main_characteristic?(text, match))

        position = match.end(0)
      end
      false
    end

    def affirmed?(text, match)
      return false if match[0].end_with?("less") || match.post_match.match?(NEGATED_AFTER)

      !negated_before?(text, match.begin(0))
    end

    def main_characteristic?(text, match)
      return true unless HEDGED_PROPERTIES.include?(property)
      return false if hedged_before?(text[0...match.begin(0)])
      return false if match.post_match.match?(HEDGED_AFTER)

      !(property == :sheen && swatch_only?(match.post_match))
    end

    def hedged_before?(head)
      tokens = head.split(CLAUSE_BOUNDARY, -1).last.to_s.scan(/[a-z'-]+/)
      (tokens.size - 1).downto([tokens.size - HEDGE_REACH - 2, 0].max) do |index|
        return true if hedge_at?(tokens, index)
        return false if NOT_BETWEEN_HEDGE.include?(tokens[index])
      end
      false
    end

    def hedge_at?(tokens, index)
      between = tokens.drop(index + 1)
      return between.size <= HEDGE_REACH if HEDGES.include?(tokens[index])
      return false unless HEDGE_NOUNS.include?(tokens[index]) && between.first == "of"

      between.size <= HEDGE_REACH + 1 && tokens[[index - 2, 0].max...index] != QUITE_A
    end

    def swatch_only?(tail)
      swatch = SWATCH_ONLY.match(tail)
      swatch.present? && !swatch.post_match.match?(ALSO_IN_WRITING)
    end

    def negated_before?(text, position)
      head = text[0...position]
      words = head.split(CLAUSE_BOUNDARY, -1).last.to_s.scan(WORD).last(WINDOW)
      return true if words.any? { |word| blocks?(word) } || words.each_cons(2).include?(%w[as with])

      negated_list_item?(text, head)
    end

    def negated_list_item?(text, head)
      separator = LIST_TAIL.match(head)
      return false unless separator

      previous = TERM_AT_END.match(head[0...separator.begin(0)].rstrip)
      previous.present? && negated_before?(text, previous.begin(0))
    end

    def blocks?(word)
      return true if NEGATIONS.include?(word) || COMPARISONS.include?(word)
      return true if word.end_with?("n't")

      property == :water_resistant && WEAK_QUALIFIERS.include?(word)
    end
  end
end
