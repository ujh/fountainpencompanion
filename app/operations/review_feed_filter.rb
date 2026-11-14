class ReviewFeedFilter
  Match = Data.define(:rule, :text)

  MIN_BRAND_LENGTH = 3
  MAX_TEXT_LENGTH = 1000

  BRAND_STOPLIST = [
    "alchemy",
    "backpack",
    "before breakfast",
    "black cat",
    "boss",
    "camel",
    "chinese school",
    "crescent",
    "cross",
    "delta",
    "dollar",
    "elixir",
    "endless",
    "fear",
    "flair",
    "glare",
    "handy",
    "hatch",
    "hero",
    "honour",
    "jolly",
    "jot",
    "joyful",
    "life line",
    "lighthouse",
    "loft",
    "manuscript",
    "modern",
    "monogram",
    "nine",
    "online",
    "oriental",
    "original",
    "panache",
    "papyrus",
    "pen box",
    "personal",
    "queen",
    "reform",
    "scribe",
    "sketch",
    "tag",
    "the writing desk",
    "there",
    "tiger",
    "universal",
    "unknown",
    "vintage",
    "voice",
    "zodiac"
  ].to_set.freeze

  CATEGORY_WORD = /(?<![[:alnum:]])ink/i
  TITLE_KEYWORD = /(?<![[:alnum:]])(ink|swatch)/i

  def self.brand_names
    BrandCluster.pluck(:name) +
      MacroCluster.where.not(brand_cluster_id: nil).distinct.pluck(:brand_name)
  end

  def initialize(brand_names: self.class.brand_names)
    self.brand_pattern = build_brand_pattern(brand_names)
  end

  def match(item)
    category_match(item[:categories]) || brand_match(item[:title]) || keyword_match(item[:title])
  end

  private

  attr_accessor :brand_pattern

  def category_match(categories)
    category = Array(categories).find { |c| CATEGORY_WORD.match?(truncate(c)) }
    Match.new(rule: :category, text: category) if category
  end

  def brand_match(title)
    found = brand_pattern&.match(truncate(title))
    Match.new(rule: :brand, text: found[0]) if found
  end

  def keyword_match(title)
    found = TITLE_KEYWORD.match(truncate(title))
    Match.new(rule: :keyword, text: found[1].downcase) if found
  end

  def truncate(text)
    text.to_s[0, MAX_TEXT_LENGTH]
  end

  def build_brand_pattern(names)
    alternatives =
      names
        .map { |name| name.to_s.squish }
        .select { |name| name.length >= MIN_BRAND_LENGTH }
        .reject { |name| BRAND_STOPLIST.include?(normalize(name)) }
        .uniq { |name| normalize(name) }
        .sort_by { |name| -name.length }
        .map { |name| pattern_for(name) }
    return if alternatives.empty?

    /(?<![[:alnum:]])(?:#{alternatives.join("|")})(?![[:alnum:]])/i
  end

  def pattern_for(name)
    Regexp.escape(name).gsub("\\ ", "[[:space:]]+").gsub(/['’]/, "['’]")
  end

  def normalize(name)
    name.downcase.tr("’", "'")
  end
end
