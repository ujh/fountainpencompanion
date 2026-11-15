class Kramdown::Converter::FpcHtml < Kramdown::Converter::Html
  def convert_p(el, indent)
    if el.options[:transparent]
      inner(el, indent)
    elsif el.children.size == 1 && el.children.first.type == :img
      figure(el.children.first, indent)
    else
      super
    end
  end

  private

  def figure(img, indent)
    caption = img.attr["title"] ? "<figcaption>#{img.attr["title"]}</figcaption>" : ""
    "#{" " * indent}<figure><img#{html_attributes(img.attr)} />#{caption}</figure>\n"
  end
end
