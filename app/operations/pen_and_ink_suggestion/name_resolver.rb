class PenAndInkSuggestion::NameResolver
  MAX_PINS = 5
  TIE_SHARE = 0.9
  CLOSEST_DISTANCE = 2
  WEIGHTS = { brand: 2, line: 2, name: 2, extra: 1 }.freeze
  BRANDISH = %i[brand line].freeze
  SIDES = %i[pen ink].freeze
  NOT_FOUND_NOTE = "I couldn't find \"%<mention>s\" in your collection."
  CLOSEST_NOTE =
    "I couldn't find \"%<mention>s\" in your collection, so I went with the closest: %<closest>s."
  UNUSABLE_NOTES = {
    pen: "I left out %<name>s: it isn't a fountain pen I can suggest an ink for.",
    ink: "I left out %<name>s: a swab can't fill a pen."
  }.freeze

  Resolution =
    Data.define(:pen_pins, :ink_pins, :pen_brand_filter, :ink_brand_filter, :notes) do
      def self.empty
        new(pen_pins: [], ink_pins: [], pen_brand_filter: nil, ink_brand_filter: nil, notes: [])
      end

      def pins(side) = side == :pen ? pen_pins : ink_pins

      def brand_filter(side) = side == :pen ? pen_brand_filter : ink_brand_filter

      def pinned?(item) = pen_pins.include?(item) || ink_pins.include?(item)

      def pins? = pen_pins.any? || ink_pins.any?

      def log_pins
        pen_pins.map { |pen| { "pen_id" => pen.id } } +
          ink_pins.map { |ink| { "ink_id" => ink.id } }
      end
    end

  attr_accessor :snapshot, :index

  def self.call(snapshot, mentions, index: PenAndInkSuggestion::NameIndex.for(snapshot))
    new(snapshot:, index:).call(mentions)
  end

  def initialize(snapshot:, index: PenAndInkSuggestion::NameIndex.for(snapshot))
    self.snapshot = snapshot
    self.index = index
  end

  def call(mentions)
    pins = SIDES.index_with { [] }
    filters = {}
    notes = []
    mentions.each do |mention|
      outcome = resolve(mention)
      outcome[:pins].each { |side, items| pins[side] |= items }
      outcome[:filters].each { |side, items| filters[side] = (filters[side] || []) | items }
      notes << outcome[:note] if outcome[:note]
    end
    SIDES.each do |side|
      usable, unusable = pins[side].partition { |item| usable?(item) }
      notes.concat(
        unusable.map { |item| format(UNUSABLE_NOTES.fetch(side), name: display_name(item)) }
      )
      pins[side] = usable
    end
    Resolution.new(
      pen_pins: pins[:pen].first(MAX_PINS),
      ink_pins: pins[:ink].first(MAX_PINS),
      pen_brand_filter: filters[:pen],
      ink_brand_filter: filters[:ink],
      notes:
    )
  end

  private

  def vocabulary = PenAndInkSuggestion::MentionVocabulary

  def usable?(item)
    usable_items.include?(item)
  end

  def usable_items
    @usable_items ||= (snapshot.inkable_pens + snapshot.fillable_inks).to_set
  end

  def resolve(mention)
    words = PenAndInkSuggestion::NameText.words(mention.text)
    sides = mention.side == :any ? SIDES : [mention.side]
    matches = sides.flat_map { |side| index.matches(words, side:) }
    scored = matches.to_h { |match| [match, score(match, words)] }
    named = matches.select { |match| named?(match, words) }

    if named.any?
      { pins: pins_for(named, scored), filters: {} }
    elsif (brand_matches = brand_only(matches, words)).any?
      { pins: {}, filters: by_side(brand_matches) }
    else
      not_found(mention, matches, words)
    end
  end

  def score(match, words)
    words.each_index.sum do |position|
      field = match.covered[position]
      field && !vocabulary.filler?(words[position]) ? WEIGHTS.fetch(field) : 0
    end
  end

  def named?(match, words)
    positions = words.each_index.reject { |position| vocabulary.filler?(words[position]) }
    positions.any? { |position| match.covered[position] == :name } &&
      positions.none? { |position| code?(words[position]) && !match.covered[position] }
  end

  def code?(word)
    word.match?(/\d/)
  end

  def pins_for(named, scored)
    best = named.map { |match| scored[match] }.max
    tied = named.select { |match| scored[match] >= best * TIE_SHARE }
    by_side(tied.sort_by { |match| [-scored[match], novelty_key(match.item)] }.first(MAX_PINS))
  end

  def brand_only(matches, words)
    content = words.each_index.reject { |position| vocabulary.filler?(words[position]) }
    return [] if content.empty?

    matches.select do |match|
      content.all? { |position| BRANDISH.include?(match.covered[position]) }
    end
  end

  def not_found(mention, matches, words)
    rest = rest_words(matches, words)
    closest = closest_matches(matches, rest)
    if closest.any?
      names = closest.map { |match| display_name(match.item) }.uniq.join(" and ")
      note = format(CLOSEST_NOTE, mention: text(mention), closest: names)
      { pins: by_side(closest), filters: {}, note: }
    else
      { pins: {}, filters: {}, note: format(NOT_FOUND_NOTE, mention: text(mention)) }
    end
  end

  def rest_words(matches, words)
    words
      .each_index
      .reject do |position|
        vocabulary.filler?(words[position]) ||
          matches.any? { |match| BRANDISH.include?(match.covered[position]) }
      end
      .map { |position| words[position] }
  end

  def closest_matches(matches, rest)
    return [] if rest.empty?

    wanted = rest.join
    candidates =
      matches
        .select { |match| match.covered.intersect?(BRANDISH) }
        .to_h { |match| [match, PenAndInkSuggestion::NameText.distance(wanted, name_form(match))] }
    best = candidates.values.min
    return [] unless best && best <= CLOSEST_DISTANCE

    candidates.select { |_match, distance| distance == best }.keys.first(MAX_PINS)
  end

  def name_form(match)
    match.entry.fields.fetch(:name).join
  end

  def by_side(matches)
    matches.group_by(&:side).transform_values { |side_matches| side_matches.map(&:item) }
  end

  def novelty_key(item)
    stats = snapshot.stats_for(item)
    [stats.last_activity_on ? 1 : 0, stats.last_activity_on || Date.new(0), item.id]
  end

  def display_name(item)
    item.is_a?(CollectedPen) ? "#{item.brand} #{item.model}".squish : item.short_name
  end

  def text(mention)
    mention.text.to_s.squish
  end
end
