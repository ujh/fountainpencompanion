class PenAndInkSuggestion::ConstraintCheck
  NARROW_WIDTH = 3
  BROADISH_WIDTH = 4
  BROAD_WIDTH = 5

  attr_accessor :snapshot

  def initialize(snapshot)
    self.snapshot = snapshot
  end

  def failures(item, paths, constraints)
    paths.reject { |path| satisfies?(item, path, constraints) }
  end

  def satisfies?(item, path, constraints)
    side, name = path.split(".")
    value = constraints.value(path)
    if side == "pen"
      pen_satisfies?(item, name, value, constraints.nib_width_slack)
    else
      ink_satisfies?(item, name, value)
    end
  end

  def pair_satisfies?(pen, ink, constraints)
    case constraints.pair_usage
    when "new"
      !paired?(pen, ink)
    when "repeat"
      paired?(pen, ink)
    else
      true
    end
  end

  def paired?(pen, ink)
    snapshot.pair_history.key?([pen.id, ink.id])
  end

  def unknown_nib?(pen)
    snapshot.nib_profile(pen).width.nil?
  end

  def scented?(ink)
    properties(ink).scented?
  end

  def violation_for(pen:, ink:, constraints:)
    pen_failure = failures(pen, filter_paths(:pen, constraints), constraints).first
    if pen_failure
      return(
        "#{pen.brand} #{pen.model} does not meet the user's requirement #{pen_failure}; " \
          "choose another pen from PENS."
      )
    end

    ink_failure = failures(ink, filter_paths(:ink, constraints), constraints).first
    if ink_failure
      return(
        "#{ink.short_name} does not meet the user's requirement #{ink_failure}; " \
          "choose another ink from INKS."
      )
    end

    return if pair_satisfies?(pen, ink, constraints)

    if constraints.pair_usage == "new"
      "That pen and ink were inked together before and the user wants a new pairing; " \
        "choose another."
    else
      "That pen and ink were never inked together and the user wants a pairing used before; " \
        "choose a pairing marked \"paired before\"."
    end
  end

  private

  def filter_paths(side, constraints)
    constraints.exclusions(side) + constraints.inclusions(side)
  end

  def pen_satisfies?(pen, name, value, slack)
    profile = snapshot.nib_profile(pen)
    case name
    when "exclude_mentions"
      value.none? { |mention| mentions?([pen.brand, pen.model], mention) }
    when "comment_exclude"
      value.none? { |text| pen.comment.to_s.downcase.include?(text.downcase) }
    when "nib_grades_include"
      value.any? { |grade| profile.matches_grade?(grade) }
    when "nib_grades_exclude"
      value.none? { |grade| profile.matches_grade?(grade) }
    when "nib_width"
      width_satisfies?(profile, value, slack)
    when "nib_characters_include"
      profile.characters.map(&:to_s).intersect?(value)
    when "nib_characters_exclude"
      !profile.characters.map(&:to_s).intersect?(value)
    when "usage"
      usage_satisfies?(pen, value)
    else
      raise ArgumentError, "unknown pen constraint #{name}"
    end
  end

  def width_satisfies?(profile, value, slack)
    width = profile.width
    return false unless width

    broadish_character = profile.characters.intersect?(NibProfile::BROADISH_CHARACTERS)
    case value
    when "fine"
      width <= NARROW_WIDTH + slack && !broadish_character
    when "broadish"
      width >= BROADISH_WIDTH - slack || broadish_character
    when "broad"
      width >= BROAD_WIDTH - slack
    else
      true
    end
  end

  def ink_satisfies?(ink, name, value)
    case name
    when "exclude_mentions"
      value.none? { |mention| mentions?([ink.brand_name, ink.line_name, ink.ink_name], mention) }
    when "tags_exclude"
      !snapshot.tag_names(ink).map(&:downcase).intersect?(value.map(&:downcase))
    when "kinds_include"
      value.include?(ink.kind)
    when "kinds_exclude"
      value.exclude?(ink.kind)
    when "colour_include"
      colour(ink).matches_any?(value)
    when "colour_exclude"
      !colour(ink).matches_any?(value)
    when "shimmer", "scented"
      properties(ink).include?(name.to_sym) == (value == "include")
    when "usage"
      usage_satisfies?(ink, value)
    else
      raise ArgumentError, "unknown ink constraint #{name}"
    end
  end

  def usage_satisfies?(item, value)
    used = snapshot.stats_for(item).usage_count.positive?
    case value
    when "never_used"
      !used
    when "used_before"
      used
    else
      true
    end
  end

  def mentions?(parts, mention)
    wanted = PenAndInkSuggestion::NameText.words(mention).join
    return false if wanted.empty?

    words = PenAndInkSuggestion::NameText.words(parts.compact.join(" "))
    words.each_index.any? do |start|
      (start...words.size).any? do |stop|
        PenAndInkSuggestion::NameText.same_word?(words[start..stop].join, wanted)
      end
    end
  end

  def colour(ink)
    colours[ink.id] ||= ColorProfile.for(ink)
  end

  def colours
    @colours ||= {}
  end

  def properties(ink)
    ink_properties[ink.id] ||= PenAndInkSuggestion::InkProperties.for(ink)
  end

  def ink_properties
    @ink_properties ||= {}
  end
end
