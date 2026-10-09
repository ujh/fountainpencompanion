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
    NEGATIONS = %w[no not non without never zero nor neither none lacks lacking free].freeze
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
    CLAUSE_BOUNDARY = /[.!?;:,\n\r]|\b(?:and|but)\b/
    WORD = /[a-z']+/
    NEGATED_AFTER =
      /\A(?:[\s-]*free\b|\s*[-–—:=?]\s*(?:no|none)\b|\s+(?:version|edition|variant)s?\b)/

    def self.normalise_all(texts)
      Array(texts).map { |text| text.to_s.downcase.tr("’_#", "'  ").strip }.compact_blank
    end

    def initialize(property)
      self.property = property
    end

    def match?(text, label: false)
      patterns = PATTERNS.fetch(property)
      patterns += LABEL_PATTERNS.fetch(property, []) if label
      patterns.any? { |pattern| affirmed_match?(text, pattern) }
    end

    private

    attr_accessor :property

    def affirmed_match?(text, pattern)
      position = 0
      while (match = pattern.match(text, position))
        return true if affirmed?(text, match)

        position = match.end(0)
      end
      false
    end

    def affirmed?(text, match)
      return false if match[0].end_with?("less") || match.post_match.match?(NEGATED_AFTER)

      words = preceding_words(text, match)
      words.none? { |word| blocks?(word) } && !words.each_cons(2).include?(%w[as with])
    end

    def preceding_words(text, match)
      clause = text[0...match.begin(0)].split(CLAUSE_BOUNDARY, -1).last.to_s
      clause.scan(WORD).last(WINDOW)
    end

    def blocks?(word)
      return true if NEGATIONS.include?(word) || COMPARISONS.include?(word)
      return true if word.end_with?("n't")

      property == :water_resistant && WEAK_QUALIFIERS.include?(word)
    end
  end
end
