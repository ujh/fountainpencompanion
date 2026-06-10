require "slodown"

# Project-wide markdown formatter. Subclasses Slodown::Formatter and
# tightens the default sanitize config in three ways that matter for
# stored-XSS risk on user-generated content (profile blurbs, brand and
# ink descriptions, blog posts):
#
# - `<iframe>`, `<object>`, and `<embed>` elements are stripped
#   entirely. The gem default whitelists iframes from any host
#   (`allowed_iframe_hosts = /.*/`), which lets any signed-in user
#   plant a full-page phishing overlay on a public page. We do not
#   currently embed third-party video in this app, so the simplest
#   defense is "no iframes, ever".
# - The `style` attribute is removed from the per-element `:all`
#   attribute list. The default permits inline CSS on every element,
#   which enables clickjacking overlays via `position: fixed; ...` and
#   content exfiltration via `background-image: url(...)`.
# - `allowed_iframe_hosts` is overridden to a regex that matches
#   nothing, so even if `<iframe>` is re-added to the element list in
#   the future the host gate stays closed.
class FpcFormatter < Slodown::Formatter
  STRIPPED_ELEMENTS = %w[iframe object embed].freeze

  # Matches nothing. Defense-in-depth alongside the element removal
  # above; if `iframe` is ever re-added to the allowed elements list
  # this still keeps the embed_transformer from whitelisting any host.
  NO_IFRAME_HOSTS = /\Anever-matches\z/.freeze

  def allowed_iframe_hosts
    NO_IFRAME_HOSTS
  end

  # Slodown's default transformers list contains `embed_transformer`,
  # which calls `URI(node['src'])` on every iframe/embed it sees and
  # raises on malformed input — turning any stored `<iframe src="not a
  # uri">` into a 500 / Sidekiq retry storm. Since iframes are already
  # stripped from the element list, the transformer has no work to do.
  def transformers
    []
  end

  def sanitize_config
    config = super.deep_dup
    config[:elements] = config[:elements] - STRIPPED_ELEMENTS
    config[:attributes][:all] = config[:attributes][:all] - %w[style]
    STRIPPED_ELEMENTS.each do |element|
      config[:attributes].delete(element)
      config[:protocols].delete(element)
    end
    config
  end
end
