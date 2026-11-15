require "slodown"

class FpcFormatter < Slodown::Formatter
  STRIPPED_ELEMENTS = %w[iframe object embed].freeze
  STRIPPED_ATTRIBUTES = %w[style class id].freeze
  ABSOLUTE_HTTP_URL = %r{\Ahttps?://}i
  HOST_NAME = /\A[a-z0-9_-]+(\.[a-z0-9_-]+)*\z/

  def self.render(source)
    new(source).complete.to_s.html_safe
  end

  def markdown
    convert do |current|
      document = Kramdown::Document.new(current, kramdown_options)
      Kramdown::Converter::FpcHtml.convert(document.root, document.options).first
    end
  end

  def transformers
    [image_filter]
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

  def image_filter
    lambda do |env|
      node = env[:node]
      node.unlink if env[:node_name] == "img" && !external_image_url?(node["src"])
    end
  end

  def external_image_url?(src)
    src = src.to_s.strip
    return false unless src.match?(ABSOLUTE_HTTP_URL)

    host = URI.parse(src).host.to_s.downcase.delete_suffix(".")
    host.match?(HOST_NAME) && Fountainpencompanion::HOSTS.exclude?(host)
  rescue URI::InvalidURIError
    false
  end
end
