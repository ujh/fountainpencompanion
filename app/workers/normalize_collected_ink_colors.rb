class NormalizeCollectedInkColors
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  VALID_COLOR = /\A#(\h{3}|\h{6})\z/
  BARE_HEX = /\A(\h{3}|\h{6})\z/

  def perform
    CollectedInk
      .where.not(color: "")
      .where("color !~* ?", "^#([0-9a-f]{3}|[0-9a-f]{6})$")
      .find_each { |ink| ink.update_column(:color, normalize(ink.read_attribute(:color))) }
  end

  private

  def normalize(color)
    value = color.strip
    return value if value.match?(VALID_COLOR)
    return "##{value}" if value.match?(BARE_HEX)

    Color::RGB.by_name(value.downcase) { nil }&.html || ""
  end
end
