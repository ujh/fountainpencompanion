class Unfurler
  Result = Struct.new(:url, :title, :description, :image)

  def initialize(string_or_io)
    self.document = Nokogiri::HTML(string_or_io)
  end

  def perform
    Result.new(url, title, description, image)
  end

  private

  attr_accessor :document

  def url
    url = document.at_css('meta[property="og:url"]')&.attribute('content')&.value
    url ||= document.at_css('meta[itemprop="url"]')&.attribute('content')&.value
    url ||= document.at_css('meta[name="twitter:url"]')&.attribute('content')&.value
    url ||= document.at_css('link[rel="canonical"]')&.attribute('href')&.value
  end

  def title
    title = document.at_css('meta[property="og:title"]')&.attribute('content')&.value
    title ||= document.at_css('meta[itemprop="name"]')&.attribute('content')&.value
    title ||= document.at_css('meta[name="twitter:title"]')&.attribute('content')&.value
    title ||= document.at_css('title')&.inner_html
  end

  def description
    description = document.at_css('meta[property="og:description"]')&.attribute('content')&.value
    description ||= document.at_css('meta[itemprop="description"]')&.attribute('content')&.value
    description ||= document.at_css('meta[name="twitter:description"]')&.attribute('content')&.value
    description ||= document.at_css('meta[name="description"]')&.attribute('content')&.value
  end

  def image
    image = document.at_css('meta[property="og:image"]')&.attribute('content')&.value
    image ||= document.at_css('meta[itemprop="image"]')&.attribute('content')&.value
    image ||= document.at_css('meta[name="twitter:image"]')&.attribute('content')&.value
    image ||= document.at_css('link[rel="image_src"]')&.attribute('href')&.value
  end
end