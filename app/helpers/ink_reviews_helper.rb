module InkReviewsHelper
  INK_REVIEW_LINK_REL = "noopener noreferrer".freeze

  def ink_review_link(text, url, **options)
    uri = SafeHttp.parse_uri(url)
    return content_tag(:span, text) if uri.nil? || uri.userinfo.present?

    link_to(text, uri.to_s, rel: INK_REVIEW_LINK_REL, **options)
  end

  def ink_review_submitter(ink_review)
    user = ink_review.user
    return "Deleted user" if user.nil?

    user.admin? ? "System" : user.public_name
  end
end
