class BootstrapBreadcrumbs < BreadcrumbsOnRails::Breadcrumbs::SimpleBuilder
  def render
    return "" if @elements.size < 2

    @options[:outer_tag] ||= :ol
    @options[:tag] ||= :li
    @options[:separator] ||= ""

    @context.content_tag(@options[:outer_tag], class: "breadcrumb") do
      @elements
        .collect { |element| render_element(element) }
        .join(@options[:separator])
        .html_safe
    end
  end

  def render_element(element)
    if element.path == nil
      content = compute_name(element)
    else
      content =
        @context.link_to_unless_current(
          compute_name(element),
          compute_path(element),
          element.options
        )
    end

    if @elements.last == element
      @context.content_tag(
        @options[:tag],
        content,
        class: "breadcrumb-item active",
        "aria-current": "page"
      )
    else
      @context.content_tag(@options[:tag], content, class: "breadcrumb-item")
    end
  end
end
