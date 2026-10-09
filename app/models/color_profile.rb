class ColorProfile
  FAMILIES = %w[red orange yellow green teal blue purple pink brown gray black].freeze

  HEX_FORMAT = /\A#?(\h{3}|\h{6})\z/

  HUE_FAMILIES = [
    [15, "red"],
    [45, "orange"],
    [70, "yellow"],
    [160, "green"],
    [195, "teal"],
    [255, "blue"],
    [320, "purple"],
    [340, "pink"],
    [360, "red"]
  ].freeze

  TAG_FAMILIES = {
    "aliceblue" => [],
    "antiquewhite" => [],
    "aqua" => %w[teal],
    "aquamarine" => %w[teal],
    "azure" => [],
    "beige" => [],
    "bisque" => [],
    "black" => %w[black],
    "blanchedalmond" => [],
    "blue" => %w[blue],
    "blue black" => %w[blue black],
    "blue-black" => %w[blue black],
    "blueviolet" => %w[purple],
    "blurple" => %w[blue purple],
    "brown" => %w[brown],
    "burgundy" => %w[red],
    "burlywood" => %w[brown],
    "cadetblue" => %w[blue],
    "chartreuse" => %w[green],
    "chocolate" => %w[brown],
    "coral" => %w[orange],
    "cornflowerblue" => %w[blue],
    "cornsilk" => [],
    "crimson" => %w[red],
    "cyan" => %w[teal],
    "dark blue" => %w[blue],
    "darkblue" => %w[blue],
    "darkcyan" => %w[teal],
    "darkgoldenrod" => %w[yellow],
    "darkgray" => %w[gray],
    "darkgreen" => %w[green],
    "darkgrey" => %w[gray],
    "darkkhaki" => %w[yellow],
    "darkmagenta" => %w[purple],
    "darkolivegreen" => %w[green],
    "darkorange" => %w[orange],
    "darkorchid" => %w[purple],
    "darkred" => %w[red],
    "darksalmon" => %w[orange],
    "darkseagreen" => %w[green],
    "darkslateblue" => %w[blue],
    "darkslategray" => %w[gray],
    "darkslategrey" => %w[gray],
    "darkturquoise" => %w[teal],
    "darkviolet" => %w[purple],
    "deeppink" => %w[pink],
    "deepskyblue" => %w[blue],
    "dimgray" => %w[gray],
    "dimgrey" => %w[gray],
    "dodgerblue" => %w[blue],
    "firebrick" => %w[red],
    "floralwhite" => [],
    "forestgreen" => %w[green],
    "fuchsia" => %w[pink],
    "gainsboro" => %w[gray],
    "ghostwhite" => [],
    "gold" => %w[yellow],
    "goldenrod" => %w[yellow],
    "gray" => %w[gray],
    "green" => %w[green],
    "greenyellow" => %w[green],
    "grey" => %w[gray],
    "honeydew" => [],
    "hotpink" => %w[pink],
    "indianred" => %w[red],
    "indigo" => %w[purple],
    "ivory" => [],
    "khaki" => %w[yellow],
    "lavender" => %w[purple],
    "lavenderblush" => [],
    "lawngreen" => %w[green],
    "lemonchiffon" => %w[yellow],
    "lightblue" => %w[blue],
    "lightcoral" => %w[pink],
    "lightcyan" => %w[teal],
    "lightgoldenrodyellow" => %w[yellow],
    "lightgray" => %w[gray],
    "lightgreen" => %w[green],
    "lightgrey" => %w[gray],
    "lightpink" => %w[pink],
    "lightsalmon" => %w[orange],
    "lightseagreen" => %w[teal],
    "lightskyblue" => %w[blue],
    "lightslategray" => %w[gray],
    "lightslategrey" => %w[gray],
    "lightsteelblue" => %w[blue],
    "lightyellow" => %w[yellow],
    "lime" => %w[green],
    "limegreen" => %w[green],
    "linen" => [],
    "magenta" => %w[pink],
    "maroon" => %w[red],
    "mediumaquamarine" => %w[teal],
    "mediumblue" => %w[blue],
    "mediumorchid" => %w[purple],
    "mediumpurple" => %w[purple],
    "mediumseagreen" => %w[green],
    "mediumslateblue" => %w[blue],
    "mediumspringgreen" => %w[green],
    "mediumturquoise" => %w[teal],
    "mediumvioletred" => %w[pink],
    "midnightblue" => %w[blue],
    "mintcream" => [],
    "mistyrose" => [],
    "moccasin" => [],
    "navajowhite" => [],
    "navy" => %w[blue],
    "oldlace" => [],
    "olive" => %w[green],
    "olivedrab" => %w[green],
    "orange" => %w[orange],
    "orangered" => %w[orange],
    "orchid" => %w[purple],
    "palegoldenrod" => %w[yellow],
    "palegreen" => %w[green],
    "paleturquoise" => %w[teal],
    "palevioletred" => %w[pink],
    "papayawhip" => [],
    "peachpuff" => [],
    "peru" => %w[brown],
    "pink" => %w[pink],
    "plum" => %w[purple],
    "powderblue" => %w[blue],
    "purple" => %w[purple],
    "red" => %w[red],
    "rosybrown" => %w[brown],
    "royalblue" => %w[blue],
    "saddlebrown" => %w[brown],
    "salmon" => %w[orange],
    "sandybrown" => %w[brown],
    "seagreen" => %w[green],
    "seashell" => [],
    "sepia" => %w[brown],
    "sienna" => %w[brown],
    "silver" => %w[gray],
    "skyblue" => %w[blue],
    "slateblue" => %w[blue],
    "slategray" => %w[gray],
    "slategrey" => %w[gray],
    "snow" => [],
    "springgreen" => %w[green],
    "steelblue" => %w[blue],
    "tan" => %w[brown],
    "teal" => %w[teal],
    "thistle" => %w[purple],
    "tomato" => %w[red],
    "turquoise" => %w[teal],
    "violet" => %w[purple],
    "wheat" => [],
    "white" => [],
    "whitesmoke" => [],
    "yellow" => %w[yellow],
    "yellowgreen" => %w[green]
  }.freeze

  attr_accessor :hex, :family, :secondary_family, :lightness, :saturation, :tags

  def self.from_hex(hex, tags: [])
    hex = hex.to_s.strip
    return new(tags:) unless hex.match?(HEX_FORMAT)

    Classifier.new(Color::RGB.from_html(hex)).profile(tags:)
  end

  def self.for(collected_ink)
    hex =
      [collected_ink.read_attribute(:color), collected_ink.cluster_color].find do |value|
        value.to_s.strip.match?(HEX_FORMAT)
      end
    from_hex(hex, tags: collected_ink.cluster_tags)
  end

  def self.tag_families(tag)
    TAG_FAMILIES.fetch(tag.to_s.strip.downcase, [])
  end

  def initialize(
    hex: nil,
    family: nil,
    secondary_family: nil,
    lightness: nil,
    saturation: nil,
    tags: []
  )
    self.hex = hex
    self.family = family
    self.secondary_family = secondary_family
    self.lightness = lightness
    self.saturation = saturation
    self.tags = Array(tags)
  end

  def known?
    family.present?
  end

  def families
    [family, secondary_family].compact
  end

  def tag_families
    tags.flat_map { |tag| self.class.tag_families(tag) }.uniq
  end

  def matches?(requested_family)
    requested_family = requested_family.to_s.strip.downcase
    families.include?(requested_family) || tag_families.include?(requested_family)
  end

  def matches_any?(requested_families)
    Array(requested_families).any? { |requested_family| matches?(requested_family) }
  end

  def label
    [family, lightness].compact.join(", ").presence
  end

  class Classifier
    ACHROMATIC_CHROMA = 10
    TINT_CHROMA = 5
    BLACK_LIGHTNESS = 30
    NEAR_BLACK_LIGHTNESS = 20
    NEAR_BLACK_CHROMA = 25
    SHADE_BLACK_LIGHTNESS = 25
    GRAYISH_CHROMA = 22
    DARK_LIGHTNESS = 35
    LIGHT_LIGHTNESS = 65
    VIVID_CHROMA = 40
    HUE_MARGIN = 8
    TEAL_MIDPOINT = 177.5

    def initialize(rgb)
      lab = rgb.to_lab
      self.rgb = rgb
      self.lightness_value = lab.l
      self.chroma = Math.hypot(lab.a, lab.b)
      self.hue = rgb.to_hsl.hue % 360
    end

    def profile(tags:)
      primary, secondary = families
      ColorProfile.new(
        hex: rgb.html,
        family: primary,
        secondary_family: secondary,
        lightness:,
        saturation:,
        tags:
      )
    end

    private

    attr_accessor :rgb, :lightness_value, :chroma, :hue

    def lightness
      if lightness_value >= LIGHT_LIGHTNESS
        "light"
      elsif lightness_value < DARK_LIGHTNESS
        "dark"
      else
        "medium"
      end
    end

    def saturation
      chroma >= VIVID_CHROMA ? "vivid" : "muted"
    end

    def families
      if chroma < ACHROMATIC_CHROMA
        primary = achromatic_family
        [primary, first_other(primary, tint_family, other_achromatic_family)]
      elsif lightness_value < NEAR_BLACK_LIGHTNESS && chroma < NEAR_BLACK_CHROMA
        ["black", chromatic_family]
      else
        primary = chromatic_family
        [primary, first_other(primary, *secondary_candidates(primary))]
      end
    end

    def first_other(primary, *candidates)
      candidates.compact.find { |candidate| candidate != primary }
    end

    def achromatic_family
      lightness_value < BLACK_LIGHTNESS ? "black" : "gray"
    end

    def tint_family
      chromatic_family if chroma >= TINT_CHROMA
    end

    def other_achromatic_family
      return unless (lightness_value - BLACK_LIGHTNESS).abs < 5

      achromatic_family == "black" ? "gray" : "black"
    end

    def chromatic_family
      adjusted(hue_family)
    end

    def adjusted(family)
      case family
      when "red"
        return "pink" if lightness_value >= LIGHT_LIGHTNESS
        return "brown" if chroma < 30 && lightness_value.between?(NEAR_BLACK_LIGHTNESS, 60)
      when "orange"
        return "brown" if lightness_value < 55 || (chroma < 55 && lightness_value < LIGHT_LIGHTNESS)
        return "brown" if chroma < 30 && lightness_value < 85
      when "yellow"
        return hue < 55 ? "brown" : "green" if lightness_value < 55
        return "brown" if chroma < 30 && lightness_value < LIGHT_LIGHTNESS
      when "pink"
        return "purple" if lightness_value < DARK_LIGHTNESS
      end
      family
    end

    def secondary_candidates(primary)
      [
        hue_family,
        (teal_neighbour if primary == "teal"),
        hue_neighbour,
        (red_neighbour if primary == "red"),
        (magenta_neighbour if primary == "purple"),
        shade_family
      ]
    end

    def teal_neighbour
      hue < TEAL_MIDPOINT ? "green" : "blue"
    end

    def red_neighbour
      return "pink" if lightness_value >= 45 && chroma < 50

      "brown" if chroma < 40 && lightness_value < 45
    end

    def magenta_neighbour
      "pink" if hue >= 290 && lightness_value >= 45
    end

    def hue_neighbour
      HUE_FAMILIES.each_cons(2) do |(limit, below), (_next_limit, above)|
        next if below == above
        return adjusted(above) if hue >= limit - HUE_MARGIN && hue < limit
        return adjusted(below) if hue >= limit && hue < limit + HUE_MARGIN
      end
      nil
    end

    def shade_family
      return "black" if lightness_value < SHADE_BLACK_LIGHTNESS

      "gray" if chroma < GRAYISH_CHROMA
    end

    def hue_family
      HUE_FAMILIES.find { |limit, _family| hue < limit }.last
    end
  end
end
