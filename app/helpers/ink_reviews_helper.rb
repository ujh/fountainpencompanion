module InkReviewsHelper
  # Review URLs are scraped from third-party pages and stored, so they are
  # user generated content. Only ever render them as links when they are
  # plain http(s) URLs without embedded credentials; otherwise fall back to
  # the text alone. Links carry `rel="noopener noreferrer"`; reviewers keep
  # a followed link on purpose.
  INK_REVIEW_LINK_REL = "noopener noreferrer".freeze

  def ink_review_link(text, url, **options)
    uri = SafeHttp.parse_uri(url)
    return content_tag(:span, text) if uri.nil? || uri.userinfo.present?

    link_to(text, uri.to_s, rel: INK_REVIEW_LINK_REL, **options)
  end
end
