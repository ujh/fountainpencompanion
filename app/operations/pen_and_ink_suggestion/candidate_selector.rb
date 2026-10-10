class PenAndInkSuggestion::CandidateSelector
  SLICES = {
    free: {
      pens: 25,
      inks: 40,
      currently_inked: 15,
      full_descriptions: 5
    },
    premium: {
      pens: 40,
      inks: 80,
      currently_inked: 40,
      full_descriptions: 10
    },
    admin: {
      pens: 60,
      inks: 120,
      currently_inked: 40,
      full_descriptions: 10
    }
  }.freeze
  FALLBACK_SLICES = {
    free: {
      pens: 50,
      inks: 50,
      currently_inked: 15,
      full_descriptions: 5
    },
    premium: {
      pens: 100,
      inks: 100,
      currently_inked: 40,
      full_descriptions: 10
    },
    admin: {
      pens: 200,
      inks: 200,
      currently_inked: 40,
      full_descriptions: 10
    }
  }.freeze
  NOVELTY_SHARE = 0.8
  JITTER_DAYS = 60
  SIDES = %i[pen ink].freeze
  BRAND_FILTER_DROPPED_NOTES = {
    pen: "None of your uninked pens is of the brand you named, so I chose from all of them.",
    ink: "None of your inks is of the brand you named, so I chose from all of them."
  }.freeze
  PINNED_CARTRIDGE_DROPPED_NOTE =
    "I left out %<name>s: it's a cartridge ink, and none of the pens I chose from takes cartridges."
  OUT_OF_SCOPE_NOTE =
    "That request is outside what I can do, so here is a pen and ink from your collection instead."
  REQUESTED_COUNT_NOTE = "I suggest one combination at a time; use \"Try again!\" for another one."

  RELAX_STEPS = {
    pen: [
      [:drop, %w[pen.usage]],
      [:drop, %w[pen.nib_characters_include]],
      [:widen, %w[pen.nib_width pen.nib_grades_include]],
      [:drop, %w[pen.nib_width pen.nib_grades_include]]
    ],
    ink: [
      [:drop, %w[ink.usage]],
      [:drop, %w[ink.shimmer]],
      [:widen, %w[ink.colour_include]],
      [:drop, %w[ink.colour_include]],
      [:drop, %w[ink.kinds_include]]
    ]
  }.freeze
  NIB_FILTERS = %w[pen.nib_grades_include pen.nib_width pen.nib_characters_include].freeze
  COLOUR_NEIGHBOURS = {
    "red" => %w[orange pink brown],
    "orange" => %w[red yellow brown],
    "yellow" => %w[orange green],
    "green" => %w[yellow teal],
    "teal" => %w[green blue],
    "blue" => %w[teal purple],
    "purple" => %w[blue pink],
    "pink" => %w[purple red],
    "brown" => %w[orange red],
    "gray" => %w[black],
    "black" => %w[gray]
  }.freeze

  attr_accessor :snapshot,
                :rejected_pairs,
                :tier,
                :seed,
                :resolution,
                :fallback,
                :constraints,
                :effective_constraints

  def initialize(
    snapshot:,
    rejected_pairs: [],
    tier: :free,
    seed: nil,
    resolution: PenAndInkSuggestion::NameResolver::Resolution.empty,
    fallback: false,
    constraints: PenAndInkSuggestion::Constraints.empty
  )
    self.snapshot = snapshot
    self.rejected_pairs = rejected_pairs
    self.tier = tier
    self.seed = seed || SecureRandom.random_number(2**31)
    self.resolution = resolution
    self.fallback = fallback
    self.constraints = constraints
    self.effective_constraints = constraints
  end

  def call
    notes.concat(scope_notes)
    SIDES.each { |side| narrow_pins(side) }
    pen_pool = filtered(:pen, pens_taking(pen_base, pins(:ink)))
    return excluded_selection if excluded

    ink_pool = filtered(:ink, compatible_inks(ink_base, pen_pool))
    return excluded_selection if excluded

    pen_pool, ink_pool = pair_usage_pools(pen_pool, ink_pool)
    pen_pool = pens_taking(pen_pool, ink_pool)
    pens, = side(:pen, pen_pool, slice[:pens])
    ink_pool = repeat_inks(ink_pool, pens)
    inks, ranked_inks = side(:ink, compatible_inks(ink_pool, pens), slice[:inks])
    relax_shown_pair_usage(pens, inks)
    notes.concat(relaxation_notes)
    nib_note = unknown_nib_note
    notes << nib_note if nib_note
    note_dropped_ink_pins(inks)
    selection(
      pens:,
      inks:,
      pen_total: pins(:pen).any? ? pens.size : pen_pool.size,
      ink_total: pins(:ink).any? ? inks.size : ink_pool.size,
      full_description_inks:
        ((pins(:ink) & inks) + ranked_inks.first(slice[:full_descriptions])).uniq,
      end_reason: end_reason(pens, inks)
    )
  end

  def candidate_pens
    @candidate_pens ||= snapshot.inkable_pens.reject { |pen| snapshot.inked?(pen) }
  end

  def candidate_inks
    snapshot.fillable_inks
  end

  def pins(side)
    pins_by_side[side] ||= (resolution.pins(side) + kept_pins(side)).uniq
  end

  def log_pins
    pins(:pen).map { |pen| { "pen_id" => pen.id } } +
      pins(:ink).map { |ink| { "ink_id" => ink.id } }
  end

  def relaxations
    relaxations_by_field.values
  end

  private

  attr_accessor :excluded, :unknown_nib_count

  def selection(pens:, inks:, pen_total:, ink_total:, end_reason:, full_description_inks: [])
    PenAndInkSuggestion::Selection.new(
      pens:,
      inks:,
      pen_total:,
      ink_total:,
      full_description_inks:,
      currently_inked:,
      end_reason:,
      seed:,
      pinned_pens: pins(:pen),
      pinned_inks: pins(:ink) & inks,
      unfiltered: fallback,
      notes:,
      effective_constraints:,
      constraint_check: check,
      relaxations:,
      end_message: excluded && excluded_message
    )
  end

  def excluded_selection
    notes.concat(relaxation_notes)
    selection(pens: [], inks: [], pen_total: 0, ink_total: 0, end_reason: :excluded_all)
  end

  def check
    @check ||= PenAndInkSuggestion::ConstraintCheck.new(snapshot)
  end

  def slice
    (fallback ? FALLBACK_SLICES : SLICES).fetch(tier)
  end

  def random
    @random ||= Random.new(seed)
  end

  def notes
    @notes ||= []
  end

  def pins_by_side
    @pins_by_side ||= {}
  end

  def relaxations_by_field
    @relaxations_by_field ||= {}
  end

  def other(side)
    side == :pen ? :ink : :pen
  end

  def scope_notes
    [
      (OUT_OF_SCOPE_NOTE if constraints.out_of_scope),
      (REQUESTED_COUNT_NOTE if constraints.requested_count > 1)
    ].compact
  end

  def kept_pins(side)
    return [] unless constraints.keep_from_previous == side.to_s

    pair = rejected_pairs.last&.to_h&.stringify_keys
    id = pair && pair["#{side}_id"]
    items = side == :pen ? snapshot.inkable_pens : candidate_inks
    Array(items.find { |item| item.id == id })
  end

  def narrow_pins(side)
    pinned = pins(side)
    paths = filter_paths(side)
    return if pinned.empty? || paths.empty?

    narrowed = pinned.select { |item| passes?(item, paths) }
    if narrowed.any?
      pins_by_side[side] = narrowed
    else
      paths.each { |path| relax(path, "pinned") }
    end
  end

  def filter_paths(side)
    effective_constraints.exclusions(side) + effective_constraints.inclusions(side)
  end

  def passes?(item, paths)
    check.failures(item, paths, effective_constraints).empty?
  end

  def pen_base
    pins(:pen).presence || brand_filtered(:pen, candidate_pens)
  end

  def ink_base
    @ink_base ||= pins(:ink).presence || brand_filtered(:ink, candidate_inks)
  end

  def brand_filtered(side, items)
    filter = resolution.brand_filter(side)
    return items unless filter

    filtered = items & filter
    return filtered if filtered.any?

    notes << BRAND_FILTER_DROPPED_NOTES.fetch(side)
    items
  end

  def filtered(side, items)
    return items if pins(side).any? || items.empty?

    paths = effective_constraints.exclusions(side)
    kept = items.select { |item| passes?(item, paths) }
    if kept.empty?
      self.excluded = [side, paths.reject { |path| items.all? { |item| passes?(item, [path]) } }]
      return kept
    end
    count_unknown_nibs(kept) if side == :pen
    relaxed(side, kept)
  end

  def relaxed(side, items)
    result = included(side, items)
    RELAX_STEPS
      .fetch(side)
      .each do |step, paths|
        break if result.any?

        relaxed_paths = paths.select { |path| relax_step(step, path) }
        result = included(side, items) if relaxed_paths.any?
      end
    result
  end

  def included(side, items)
    paths = effective_constraints.inclusions(side)
    items.select { |item| passes?(item, paths) }
  end

  def relax_step(step, path)
    side = path.split(".").first.to_sym
    return false unless effective_constraints.inclusions(side).include?(path)

    if step == :drop
      relax(path, "dropped", drop_reason(path))
      return true
    end

    widened = widened(path)
    return false unless widened

    relaxations_by_field[path] = relaxation(path, "widened").merge("to" => widened.value(path))
    self.effective_constraints = widened
    true
  end

  def relax(path, step, reason = nil)
    relaxations_by_field[path] = relaxation(path, step).merge({ "reason" => reason }.compact)
    self.effective_constraints = effective_constraints.reset(path)
  end

  def relaxation(path, step)
    { "field" => path, "step" => step, "from" => constraints.value(path) }
  end

  def drop_reason(path)
    return unless path == "ink.kinds_include"

    unpaired = ink_base.select { |ink| passes?(ink, effective_constraints.exclusions(:ink)) }
    "no_fitting_pen" if included(:ink, unpaired).any?
  end

  def widened(path)
    value = effective_constraints.value(path)
    case path
    when "pen.nib_width"
      return if effective_constraints.nib_width_slack.positive?

      effective_constraints.with(path, value, nib_width_slack: 1)
    when "pen.nib_grades_include"
      grades = PenAndInkSuggestion::Constraints::GRADES
      wider =
        grades.select do |grade|
          value.any? { |wanted| (grades.index(wanted) - grades.index(grade)).abs <= 1 }
        end
      effective_constraints.with(path, wider) if wider.size > value.size
    when "ink.colour_include"
      wider = (value + value.flat_map { |family| COLOUR_NEIGHBOURS.fetch(family) }).uniq
      effective_constraints.with(path, wider) if wider.size > value.size
    end
  end

  def count_unknown_nibs(pens)
    self.unknown_nib_count = pens.count { |pen| check.unknown_nib?(pen) }
  end

  def unknown_nib_note
    count = unknown_nib_count.to_i
    return if count.zero? || !effective_constraints.inclusions(:pen).intersect?(NIB_FILTERS)

    PenAndInkSuggestion::ConstraintNotes.unknown_nibs(count)
  end

  def relaxation_notes
    PenAndInkSuggestion::ConstraintNotes.relaxations(relaxations, effective_constraints)
  end

  def excluded_message
    side, paths = excluded
    PenAndInkSuggestion::ConstraintNotes.excluded(side, paths, constraints)
  end

  def pair_usage_pools(pen_pool, ink_pool)
    case effective_constraints.pair_usage
    when "repeat"
      repeat_pools(pen_pool, ink_pool)
    when "new"
      new_pools(pen_pool, ink_pool)
    else
      [pen_pool, ink_pool]
    end
  end

  def repeat_pools(pen_pool, ink_pool)
    pens = pen_pool
    pens = pens.select { |pen| ink_pool.any? { |ink| check.paired?(pen, ink) } } if pins(
      :pen
    ).empty?
    inks = ink_pool
    inks = inks.select { |ink| pens.any? { |pen| check.paired?(pen, ink) } } if pins(:ink).empty?
    return pens, inks if pens.product(inks).any? { |pen, ink| check.paired?(pen, ink) }

    relax("pair_usage", "dropped")
    [pen_pool, ink_pool]
  end

  def new_pools(pen_pool, ink_pool)
    pinned_side = SIDES.find { |side| pins(side).any? && pins(other(side)).empty? }
    return pen_pool, ink_pool unless pinned_side

    untried = ->(item) { pins(pinned_side).any? { |pin| !paired_items?(item, pin) } }
    if pinned_side == :pen
      inks = ink_pool.select(&untried)
      return pen_pool, inks if inks.any?
    else
      pens = pen_pool.select(&untried)
      return pens, ink_pool if pens.any?
    end

    relax("pair_usage", "dropped")
    [pen_pool, ink_pool]
  end

  def repeat_inks(ink_pool, pens)
    return ink_pool unless effective_constraints.pair_usage == "repeat" && pins(:ink).empty?

    ink_pool.select { |ink| pens.any? { |pen| check.paired?(pen, ink) } }
  end

  def relax_shown_pair_usage(pens, inks)
    return if effective_constraints.pair_usage == "any"

    open = pens.product(inks).select { |pen, ink| open_pair?(pen, ink) }
    return if open.empty?
    return if open.any? { |pen, ink| check.pair_satisfies?(pen, ink, effective_constraints) }

    relax("pair_usage", "dropped")
  end

  def note_dropped_ink_pins(inks)
    (pins(:ink) - inks).each do |ink|
      notes << format(PINNED_CARTRIDGE_DROPPED_NOTE, name: ink.short_name)
    end
  end

  def pens_taking(pens, inks)
    return pens if pins(:pen).any? || inks.empty?

    pens.select do |pen|
      inks.any? { |ink| PenAndInkSuggestion::CartridgeCompatibility.compatible?(pen, ink) }
    end
  end

  def side(side, items, limit)
    return items, items if pins(side).any?

    pick(side, items, limit, pins(other(side)))
  end

  def pick(side, items, limit, other_pins)
    sort = effective_constraints.value("#{side}.sort")
    if sort == "default"
      ranked = boost(side, untried_first(novelty_order(items), other_pins))
      chosen = ranked.first((limit * NOVELTY_SHARE).round)
      chosen +=
        boost(side, untried_first(favourites(items - chosen), other_pins)).first(
          limit - chosen.size
        )
      chosen += (ranked - chosen).first(limit - chosen.size)
    else
      chosen = boost(side, sorted(items, sort)).first(limit)
    end
    [chosen.shuffle(random:), chosen]
  end

  def boost(side, items)
    return items unless side == :ink && effective_constraints.value("ink.scented") == "include"

    scented, other = items.partition { |ink| check.scented?(ink) }
    scented + other
  end

  def untried_first(items, other_pins)
    return items if other_pins.empty?

    untried, tried = items.partition { |item| other_pins.none? { |pin| paired_items?(item, pin) } }
    untried + tried
  end

  def paired_items?(item, pin)
    pen, ink = item.is_a?(CollectedPen) ? [item, pin] : [pin, item]
    check.paired?(pen, ink)
  end

  def sorted(items, sort)
    items.sort_by do |item|
      stats = snapshot.stats_for(item)
      if sort == "most_used"
        [-stats.usage_count, -stats.daily_usage_count, item.id]
      else
        [stats.last_activity_on ? 1 : 0, stats.last_activity_on || Date.new(0), item.id]
      end
    end
  end

  def novelty_order(items)
    keys = items.to_h { |item| [item, novelty_key(item)] }
    items.sort_by { |item| keys[item] }
  end

  def novelty_key(item)
    stats = snapshot.stats_for(item)
    in_pen = stats.inked? ? 1 : 0
    if stats.last_activity_on
      jitter = random.rand(-JITTER_DAYS.to_f..JITTER_DAYS.to_f)
      [in_pen, 1, (stats.last_activity_on - snapshot.today).to_i + jitter]
    else
      [in_pen, 0, random.rand]
    end
  end

  def favourites(items)
    keys =
      items.to_h do |item|
        stats = snapshot.stats_for(item)
        [item, [stats.inked? ? 1 : 0, -stats.usage_count, random.rand]]
      end
    items
      .select { |item| snapshot.stats_for(item).usage_count.positive? }
      .sort_by { |item| keys[item] }
  end

  def compatible_inks(inks, pens)
    inks.select do |ink|
      pens.any? { |pen| PenAndInkSuggestion::CartridgeCompatibility.compatible?(pen, ink) }
    end
  end

  def currently_inked
    snapshot
      .active_inkings
      .sort_by { |inking| [inking.inked_on, inking.id] }
      .reverse
      .first(slice[:currently_inked])
  end

  def end_reason(pens, inks)
    return :no_compatible_pairs if pens.empty? || inks.empty?

    :all_pairs_rejected if pens.product(inks).none? { |pen, ink| open_pair?(pen, ink) }
  end

  def open_pair?(pen, ink)
    PenAndInkSuggestion::CartridgeCompatibility.compatible?(pen, ink) &&
      rejected_pair_keys.exclude?([pen.id, ink.id])
  end

  def rejected_pair_keys
    @rejected_pair_keys ||=
      rejected_pairs.map do |pair|
        pair = pair.to_h.stringify_keys
        [pair["pen_id"], pair["ink_id"]]
      end
  end
end
