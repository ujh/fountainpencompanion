class PenAndInkSuggestion::NameHints
  MAX_NAMES = 2
  SIDES = %i[pen ink].freeze

  attr_accessor :resolver

  def self.call(snapshot, mentions, index:)
    new(snapshot:, index:).call(mentions)
  end

  def initialize(snapshot:, index:)
    self.resolver = PenAndInkSuggestion::NameResolver.new(snapshot:, index:)
  end

  def call(mentions)
    mentions.flat_map { |mention| hints(mention) }.uniq
  end

  private

  def hints(mention)
    resolution = resolver.call([mention])
    return [] if resolution.misses?

    text = mention.text.to_s.squish
    SIDES.filter_map do |side|
      if resolution.pins(side).any?
        named_hint(side, text, resolution.pins(side))
      elsif resolution.brand_filter(side).present?
        "#{side} brand: #{text}"
      end
    end
  end

  def named_hint(side, text, pins)
    names = pins.map { |item| PenAndInkSuggestion::NameResolver.display_name(item) }.uniq
    return "#{side}: #{text}" if names.one? && same_name?(names.first, text)

    "#{side}: #{text} (#{names.first(MAX_NAMES).join(" / ")})"
  end

  def same_name?(name, text)
    PenAndInkSuggestion::NameText.words(name) == PenAndInkSuggestion::NameText.words(text)
  end
end
