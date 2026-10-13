class PenAndInkSuggestion::Selection
  REF_FORMAT = /\A\s*([PI])(\d+)\s*\z/i

  attr_accessor :pens,
                :inks,
                :pen_total,
                :ink_total,
                :full_description_inks,
                :currently_inked,
                :end_reason,
                :seed,
                :pinned_pens,
                :pinned_inks,
                :unfiltered,
                :notes,
                :effective_constraints,
                :constraint_check,
                :relaxations,
                :end_message

  def initialize(
    pens:,
    inks:,
    pen_total:,
    ink_total:,
    full_description_inks: [],
    currently_inked: [],
    end_reason: nil,
    seed: nil,
    pinned_pens: [],
    pinned_inks: [],
    unfiltered: false,
    notes: [],
    effective_constraints: PenAndInkSuggestion::Constraints.empty,
    constraint_check: nil,
    relaxations: [],
    end_message: nil
  )
    self.pens = pens
    self.inks = inks
    self.pen_total = pen_total
    self.ink_total = ink_total
    self.full_description_inks = full_description_inks
    self.currently_inked = currently_inked
    self.end_reason = end_reason
    self.seed = seed
    self.pinned_pens = pinned_pens
    self.pinned_inks = pinned_inks
    self.unfiltered = unfiltered
    self.notes = notes
    self.effective_constraints = effective_constraints
    self.constraint_check = constraint_check
    self.relaxations = relaxations
    self.end_message = end_message
  end

  def ended?
    end_reason.present?
  end

  def pinned?(item)
    pinned_pens.include?(item) || pinned_inks.include?(item)
  end

  def unfiltered?
    unfiltered
  end

  def constrained?
    effective_constraints.filters?
  end

  def pen_ref(pen)
    "P#{pens.index(pen) + 1}"
  end

  def ink_ref(ink)
    "I#{inks.index(ink) + 1}"
  end

  def pen_for(ref)
    item_for(ref, "P", pens)
  end

  def ink_for(ref)
    item_for(ref, "I", inks)
  end

  def full_description?(ink)
    full_description_inks.include?(ink)
  end

  def better_named_pen(pen, name)
    better_named(pens, pen, name) { |item| pen_name_parts(item) }
  end

  def better_named_ink(ink, name)
    better_named(inks, ink, name) { |item| [item.brand_name, item.line_name, item.ink_name] }
  end

  def pen_display_name(pen)
    ["#{pen.brand} #{pen.model}", pen.color, pen.material, pen.trim_color].compact_blank.join(", ")
  end

  def violation_for(pen:, ink:)
    return "#{pen.name} is not a pen from PENS." unless pens.include?(pen)
    return "#{ink.name} is not an ink from INKS." unless inks.include?(ink)
    return "A swab can't fill a pen; choose another ink." if ink.kind == "swab"
    unless PenAndInkSuggestion::CartridgeCompatibility.compatible?(pen, ink)
      return(
        "#{ink.short_name} is a cartridge ink and #{pen.brand} #{pen.model} takes no " \
          "cartridges; choose a different pen or ink."
      )
    end

    constraint_check&.violation_for(pen:, ink:, constraints: effective_constraints)
  end

  def shown_pen_ids
    pens.map(&:id)
  end

  def shown_ink_ids
    inks.map(&:id)
  end

  private

  def better_named(items, chosen, name)
    wanted = tokens(name)
    return if wanted.empty?

    scores = items.to_h { |item| [item, (tokens(yield(item)) & wanted).size] }
    best = items.max_by { |item| scores[item] }
    best if scores[best] > scores[chosen]
  end

  def pen_name_parts(pen)
    [pen.brand, pen.model, pen.color, pen.material, pen.trim_color, pen.nib]
  end

  def tokens(text)
    Array(text).join(" ").downcase.scan(/[[:alnum:]]+/).uniq
  end

  def item_for(ref, prefix, items)
    match = REF_FORMAT.match(ref.to_s)
    return unless match && match[1].upcase == prefix

    index = match[2].to_i - 1
    items[index] if index >= 0
  end
end
