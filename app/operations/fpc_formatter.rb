require "slodown"
require "timeout"

class FpcFormatter < Slodown::Formatter
  STRIPPED_ELEMENTS = %w[iframe object embed].freeze
  STRIPPED_ATTRIBUTES = %w[style class id].freeze
  ABSOLUTE_HTTP_URL = %r{\Ahttps?://}i
  HOST_NAME = /\A[a-z0-9_-]+(\.[a-z0-9_-]+)*\z/
  MAX_BRACKET_DEPTH = 5
  RENDER_TIMEOUT = 0.5
  FORMAT_VERSION = 1
  CACHE_EXPIRY = 4.weeks

  class RenderTimeout < StandardError
  end

  def self.render(source)
    html =
      Rails
        .cache
        .fetch(cache_key(source), expires_in: CACHE_EXPIRY) { String.new(render_uncached(source)) }
    html.html_safe
  end

  def self.cache_key(source)
    ["markdown", name, FORMAT_VERSION, Digest::SHA256.hexdigest(source.to_s)].join("/")
  end

  def self.too_deeply_nested?(source)
    bracket_depth(source) > MAX_BRACKET_DEPTH
  end

  def self.too_slow_to_render?(source)
    timed_render(source)
    false
  rescue RenderTimeout
    true
  rescue Kramdown::Error, ArgumentError, SystemStackError
    false
  end

  def self.bracket_depth(source)
    depth = max = 0
    source
      .to_s
      .scan(/[\[\]]/) do |bracket|
        depth = bracket == "[" ? depth + 1 : [depth - 1, 0].max
        max = depth if depth > max
      end
    max
  end

  def self.render_uncached(source)
    return plain_text(source) if too_deeply_nested?(source)

    timed_render(source)
  rescue RenderTimeout, Kramdown::Error, ArgumentError, SystemStackError
    plain_text(source)
  end
  private_class_method :render_uncached

  def self.timed_render(source)
    Timeout.timeout(RENDER_TIMEOUT, RenderTimeout) { new(source).complete.to_s }
  end
  private_class_method :timed_render

  def self.plain_text(source)
    ActionController::Base.helpers.simple_format(ERB::Util.html_escape(source.to_s))
  end
  private_class_method :plain_text

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
