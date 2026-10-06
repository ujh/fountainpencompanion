require "slodown"

class FpcFormatter < Slodown::Formatter
  STRIPPED_ELEMENTS = %w[iframe object embed].freeze
  STRIPPED_ATTRIBUTES = %w[style class id].freeze

  def self.render(source)
    new(source).complete.to_s.html_safe
  end

  def transformers
    []
  end

  def sanitize_config
    config = super.deep_dup
    config[:elements] = config[:elements] - STRIPPED_ELEMENTS
    config[:attributes][:all] = config[:attributes][:all] - stripped_attributes
    STRIPPED_ELEMENTS.each do |element|
      config[:attributes].delete(element)
      config[:protocols].delete(element)
    end
    config
  end

  private

  def stripped_attributes
    STRIPPED_ATTRIBUTES
  end
end
