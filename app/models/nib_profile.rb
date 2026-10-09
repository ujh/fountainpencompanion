# Implements docs/nib-reference.md, which is the source of truth for these rules.
class NibProfile
  WIDTH_CLASS_LIMITS = { 1 => 0.27, 2 => 0.37, 3 => 0.49, 4 => 0.69, 5 => 0.94, 6 => 1.24 }.freeze
  WIDTH_CLASS_LABELS = {
    1 => "XXF",
    2 => "EF",
    3 => "F",
    4 => "M",
    5 => "B",
    6 => "BB",
    7 => "BBB+"
  }.freeze

  GRADE_WIDTHS = {
    "UEF" => {
      western: 0.20,
      japanese: 0.17
    },
    "EEF" => {
      western: 0.25,
      japanese: 0.20
    },
    "EF" => {
      western: 0.35,
      japanese: 0.25
    },
    "F" => {
      western: 0.45,
      japanese: 0.32
    },
    "MF" => {
      western: 0.50,
      japanese: 0.40
    },
    "M" => {
      western: 0.60,
      japanese: 0.48
    },
    "B" => {
      western: 0.80,
      japanese: 0.62
    },
    "BB" => {
      western: 1.05,
      japanese: 0.80
    },
    "BBB" => {
      western: 1.30,
      japanese: 1.00
    },
    "C" => {
      western: 0.90,
      japanese: 0.90
    }
  }.freeze

  BROADISH_CHARACTERS = %i[stub italic fude music architect zoom naginata parallel].freeze

  attr_accessor :raw,
                :kind,
                :grade,
                :width,
                :width_min,
                :width_max,
                :characters,
                :material,
                :japanese_sizing,
                :confidence,
                :source,
                :source_text

  def self.parse(nib, brand: nil, model: nil)
    Parser.new(nib, brand:, model:).profile
  end

  def self.width_class(mm)
    WIDTH_CLASS_LIMITS.find { |_width, limit| mm <= limit }&.first || 7
  end

  def initialize(
    raw:,
    kind:,
    grade: nil,
    width: nil,
    width_min: nil,
    width_max: nil,
    characters: [],
    material: nil,
    japanese_sizing: false,
    confidence: :none,
    source: :nib,
    source_text: raw
  )
    self.raw = raw
    self.kind = kind
    self.grade = grade
    self.width = width
    self.width_min = width_min || width
    self.width_max = width_max || width
    self.characters = characters
    self.material = material
    self.japanese_sizing = japanese_sizing
    self.confidence = confidence
    self.source = source
    self.source_text = source_text
  end

  def fountain_pen?
    kind == :fountain
  end

  def broadish?
    return false unless width

    width >= 4 || broadish_character?
  end

  def broad?
    width.present? && width >= 5
  end

  def fine?
    width.present? && width <= 3 && !broadish_character?
  end

  def matches_grade?(requested)
    requested = requested.to_s.upcase
    return grade == requested if grade
    return false unless width && GRADE_WIDTHS.key?(requested)

    width == self.class.width_class(GRADE_WIDTHS[requested][:western])
  end

  def label
    text = source == :model ? "#{source_text} (model name)" : raw.to_s.strip
    return text.presence unless width

    [
      "#{text} → W#{width}",
      ("(Japanese)" if japanese_sizing),
      characters.map { |character| character.to_s.tr("_", " ") }.join(" ").presence,
      range_label
    ].compact.join(" ")
  end

  private

  def broadish_character?
    characters.intersect?(BROADISH_CHARACTERS)
  end

  def range_label
    return if width_min == width && width_max == width
    if width_max == width && characters.intersect?(%i[stub italic])
      return "(cross-strokes W#{width_min})"
    end

    "(W#{width_min}–W#{width_max})"
  end
end
