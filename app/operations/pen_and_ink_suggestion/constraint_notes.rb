module PenAndInkSuggestion::ConstraintNotes
  SIDE_ITEMS = { pen: "uninked pens", ink: "inks" }.freeze
  NIB_WIDTHS = { "fine" => "fine", "broadish" => "broad-ish", "broad" => "broad" }.freeze
  KINDS = {
    "bottle" => "bottled inks",
    "sample" => "ink samples",
    "cartridge" => "cartridges"
  }.freeze
  PINNED_NOTES = {
    pen: "The pens you named don't meet your other pen requirements, so I kept them anyway.",
    ink: "The inks you named don't meet your other ink requirements, so I kept them anyway."
  }.freeze
  EXCLUDED_MESSAGE =
    "None of your %<items>s is left after excluding %<excluded>s. Change your request and try again."
  UNKNOWN_NIBS_NOTE = {
    one: "1 pen without a recognisable nib size was left out of the nib filter.",
    other: "%<count>d pens without a recognisable nib size were left out of the nib filter."
  }.freeze

  module_function

  def relaxations(relaxations, effective_constraints)
    pinned, relaxed = relaxations.partition { |relaxation| relaxation["step"] == "pinned" }
    pinned_sides = pinned.map { |relaxation| side_of(relaxation["field"]) }.uniq
    pinned_sides.map { |side| PINNED_NOTES.fetch(side) } +
      relaxed.map { |relaxation| relaxation_note(relaxation, effective_constraints) }
  end

  def unknown_nibs(count)
    format(UNKNOWN_NIBS_NOTE.fetch(count == 1 ? :one : :other), count:)
  end

  def excluded(side, paths, constraints)
    labels = paths.map { |path| excluded_label(path, constraints.value(path)) }
    format(EXCLUDED_MESSAGE, items: SIDE_ITEMS.fetch(side), excluded: and_list(labels))
  end

  def relaxation_note(relaxation, effective_constraints)
    field = relaxation["field"]
    from = relaxation["from"]
    widened = relaxation["step"] == "widened"
    return pair_usage_note(from) if field == "pair_usage"

    side = side_of(field)
    subject =
      "None of your #{SIDE_ITEMS.fetch(side)}#{rest_of_request(side, field, effective_constraints)}"
    case field
    when "pen.usage", "ink.usage"
      usage_note(side, from, effective_constraints, field)
    when "pen.nib_characters_include"
      "#{subject} has #{article(or_list(from))} #{or_list(from)} nib, so I left the nib type open."
    when "pen.nib_width"
      nib = NIB_WIDTHS.fetch(from)
      if widened
        direction = from == "fine" ? "broader" : "finer"
        "#{subject} has #{article(nib)} #{nib} nib, so I went one nib size #{direction}."
      else
        "#{subject} has #{article(nib)} #{nib} nib, so I chose from all nib sizes."
      end
    when "pen.nib_grades_include"
      grades = or_list(from)
      if widened
        "#{subject} has #{article(grades)} #{grades} nib, so I included the neighbouring sizes " \
          "(#{or_list(relaxation["to"] - from)})."
      else
        "#{subject} has #{article(grades)} #{grades} nib, so I chose from all nib sizes."
      end
    when "ink.shimmer"
      "#{subject} has shimmer, so I included inks without it."
    when "ink.colour_include"
      colours = or_list(from)
      if widened
        "#{subject} is #{colours}, so I included neighbouring colours (#{or_list(relaxation["to"] - from)})."
      else
        "#{subject} is #{colours}, so I chose from all colours."
      end
    when "ink.kinds_include"
      if relaxation["reason"] == "no_fitting_pen"
        pens = rest_of_request(:pen, field, effective_constraints, "that fit your request")
        "None of your uninked pens#{pens} takes cartridges, so I picked from all your inks."
      else
        kinds = or_list(from.map { |kind| KINDS.fetch(kind) })
        "You have no #{kinds}#{rest_of_request(:ink, field, effective_constraints, "that fit")}, " \
          "so I picked from all your inks."
      end
    end
  end

  def usage_note(side, from, effective_constraints, field)
    items = SIDE_ITEMS.fetch(side)
    rest = rest_of_request(side, field, effective_constraints)
    if from == "never_used"
      "All your #{items}#{rest} have been used before, so I included those."
    else
      "None of your #{items}#{rest} has been used before, so I included new ones."
    end
  end

  def pair_usage_note(from)
    if from == "new"
      "Every pairing I could show you has been inked before, so I allowed pairings you've used."
    else
      "None of the pens and inks that fit were inked together before, so I allowed new pairings."
    end
  end

  def rest_of_request(
    side,
    field,
    effective_constraints,
    phrase = "that fit the rest of your request"
  )
    others =
      effective_constraints.exclusions(side) + effective_constraints.inclusions(side) - [field]
    others.any? ? " #{phrase}" : ""
  end

  def excluded_label(path, value)
    case path
    when "pen.exclude_mentions", "ink.exclude_mentions"
      and_list(value.map { |mention| "\"#{mention}\"" })
    when "pen.comment_exclude"
      "pens whose comment mentions #{or_list(value.map { |text| "\"#{text}\"" })}"
    when "pen.nib_grades_exclude", "pen.nib_characters_exclude"
      "#{or_list(value)} nibs"
    when "ink.tags_exclude"
      "inks tagged #{or_list(value.map { |tag| "\"#{tag}\"" })}"
    when "ink.kinds_exclude"
      or_list(value.map { |kind| KINDS.fetch(kind) })
    when "ink.colour_exclude"
      "#{or_list(value)} inks"
    when "ink.shimmer"
      "shimmer inks"
    when "ink.scented"
      "scented inks"
    end
  end

  def side_of(field)
    field.split(".").first.to_sym
  end

  def article(word)
    word.match?(/\A(?:[aeio]|M\b|MF\b|EF\b|F\b)/i) ? "an" : "a"
  end

  def or_list(words)
    words.to_sentence(two_words_connector: " or ", last_word_connector: " or ")
  end

  def and_list(words)
    words.to_sentence(two_words_connector: " and ", last_word_connector: " and ")
  end
end
