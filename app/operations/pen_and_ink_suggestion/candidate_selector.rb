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
  BRAND_FILTER_DROPPED_NOTES = {
    pen: "None of your uninked pens is of the brand you named, so I chose from all of them.",
    ink: "None of your inks is of the brand you named, so I chose from all of them."
  }.freeze

  attr_accessor :snapshot, :rejected_pairs, :tier, :seed, :resolution, :fallback

  def initialize(
    snapshot:,
    rejected_pairs: [],
    tier: :free,
    seed: nil,
    resolution: PenAndInkSuggestion::NameResolver::Resolution.empty,
    fallback: false
  )
    self.snapshot = snapshot
    self.rejected_pairs = rejected_pairs
    self.tier = tier
    self.seed = seed || SecureRandom.random_number(2**31)
    self.resolution = resolution
    self.fallback = fallback
  end

  def call
    pens, = side(:pen, pens_for_pinned_inks(pen_pool), slice[:pens])
    inks, ranked_inks = side(:ink, compatible_inks(ink_pool, pen_pool), slice[:inks])
    inks = compatible_inks(inks, pens)
    ranked_inks &= inks
    PenAndInkSuggestion::Selection.new(
      pens:,
      inks:,
      pen_total: pinned(:pen).any? ? pens.size : pen_pool.size,
      ink_total: pinned(:ink).any? ? inks.size : ink_pool.size,
      full_description_inks: (pinned(:ink) + ranked_inks.first(slice[:full_descriptions])).uniq,
      currently_inked: currently_inked,
      end_reason: end_reason(pens, inks),
      seed:,
      pinned_pens: pinned(:pen),
      pinned_inks: pinned(:ink),
      unfiltered: fallback,
      notes:
    )
  end

  def candidate_pens
    @candidate_pens ||= snapshot.inkable_pens.reject { |pen| snapshot.inked?(pen) }
  end

  def candidate_inks
    snapshot.fillable_inks
  end

  private

  def slice
    (fallback ? FALLBACK_SLICES : SLICES).fetch(tier)
  end

  def random
    @random ||= Random.new(seed)
  end

  def notes
    @notes ||= []
  end

  def pinned(side)
    resolution.pins(side)
  end

  def pen_pool
    @pen_pool ||= pinned(:pen).presence || brand_filtered(:pen, candidate_pens)
  end

  def ink_pool
    @ink_pool ||= pinned(:ink).presence || brand_filtered(:ink, candidate_inks)
  end

  def brand_filtered(side, items)
    filter = resolution.brand_filter(side)
    return items unless filter

    filtered = items & filter
    return filtered if filtered.any?

    notes << BRAND_FILTER_DROPPED_NOTES.fetch(side)
    items
  end

  def pens_for_pinned_inks(pens)
    return pens if pinned(:pen).any? || pinned(:ink).empty?

    pens.select do |pen|
      pinned(:ink).any? { |ink| PenAndInkSuggestion::CartridgeCompatibility.compatible?(pen, ink) }
    end
  end

  def side(side, items, limit)
    return items, items if pinned(side).any?

    other = pinned(side == :pen ? :ink : :pen)
    pick(items, limit, other)
  end

  def pick(items, limit, other_pins)
    ranked = boost(novelty_order(items), other_pins)
    chosen = ranked.first((limit * NOVELTY_SHARE).round)
    chosen += boost(favourites(items - chosen), other_pins).first(limit - chosen.size)
    chosen += (ranked - chosen).first(limit - chosen.size)
    [chosen.shuffle(random:), chosen]
  end

  def boost(items, other_pins)
    return items if other_pins.empty?

    untried, tried = items.partition { |item| other_pins.none? { |pin| paired?(item, pin) } }
    untried + tried
  end

  def paired?(item, pin)
    pen, ink = item.is_a?(CollectedPen) ? [item, pin] : [pin, item]
    snapshot.pair_history.key?([pen.id, ink.id])
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
