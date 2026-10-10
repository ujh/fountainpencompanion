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
  NOVELTY_SHARE = 0.8
  JITTER_DAYS = 60

  attr_accessor :snapshot, :rejected_pairs, :tier, :seed

  def initialize(snapshot:, rejected_pairs: [], tier: :free, seed: nil)
    self.snapshot = snapshot
    self.rejected_pairs = rejected_pairs
    self.tier = tier
    self.seed = seed || SecureRandom.random_number(2**31)
  end

  def call
    pens, ranked_pens = pick(candidate_pens, slice[:pens])
    inks, ranked_inks = pick(compatible_inks(candidate_inks, candidate_pens), slice[:inks])
    inks = compatible_inks(inks, pens)
    ranked_inks &= inks
    PenAndInkSuggestion::Selection.new(
      pens:,
      inks:,
      pen_total: candidate_pens.size,
      ink_total: candidate_inks.size,
      full_description_inks: ranked_inks.first(slice[:full_descriptions]),
      currently_inked: currently_inked,
      end_reason: end_reason(pens, inks),
      seed:
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
    SLICES.fetch(tier)
  end

  def random
    @random ||= Random.new(seed)
  end

  def pick(items, limit)
    ranked = novelty_order(items)
    chosen = ranked.first((limit * NOVELTY_SHARE).round)
    chosen += favourites(items - chosen).first(limit - chosen.size)
    chosen += (ranked - chosen).first(limit - chosen.size)
    [chosen.shuffle(random:), chosen]
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
