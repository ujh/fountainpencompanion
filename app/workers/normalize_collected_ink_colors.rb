class NormalizeCollectedInkColors
  include Sidekiq::Worker

  sidekiq_options queue: "low"

  BARE_HEX = /\A(\h{3}|\h{6})\z/

  def perform
    CollectedInk
      .where.not(color: "")
      .select(:id, :color)
      .find_each do |ink|
        color = ink.read_attribute(:color)
        ink.update_column(:color, normalize(color)) unless color.match?(CollectedInk::COLOR_FORMAT)
      end
  end

  private

  def normalize(color)
    value = color.strip
    return value if value.match?(CollectedInk::COLOR_FORMAT)
    return "##{value}" if value.match?(BARE_HEX)

    Color::RGB.by_name(value.downcase) { nil }&.html || ""
  end
end
