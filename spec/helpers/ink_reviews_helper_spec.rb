require "rails_helper"

describe InkReviewsHelper, type: :helper do
  def render_link(text, url, **options)
    Nokogiri::HTML.fragment(helper.ink_review_link(text, url, **options))
  end

  it "renders a link with a hardened rel for plain https urls" do
    fragment = render_link("Review", "https://example.com/review", target: "_blank")
    link = fragment.at_css("a")
    expect(link["href"]).to eq("https://example.com/review")
    expect(link["rel"]).to eq("noopener noreferrer")
    expect(link["target"]).to eq("_blank")
    expect(link.text).to eq("Review")
  end

  it "renders a link for plain http urls" do
    fragment = render_link("Review", "http://example.com/review")
    expect(fragment.at_css("a")["href"]).to eq("http://example.com/review")
  end

  it "does not render a link for javascript: urls" do
    fragment = render_link("Review", "javascript://example.com/%0aalert(1)")
    expect(fragment.at_css("a")).to be_nil
    expect(fragment.at_css("span").text).to eq("Review")
  end

  it "does not render a link for data: urls" do
    fragment = render_link("Review", "data:text/html,<script>alert(1)</script>")
    expect(fragment.at_css("a")).to be_nil
  end

  it "does not render a link for urls with embedded credentials" do
    fragment = render_link("Review", "https://user:pass@example.com/")
    expect(fragment.at_css("a")).to be_nil
  end

  it "does not render a link for unparseable urls" do
    fragment = render_link("Review", "http://exa mple.com/")
    expect(fragment.at_css("a")).to be_nil
  end

  it "escapes the link text" do
    html = helper.ink_review_link("<script>x</script>", "https://example.com/")
    expect(html).not_to include("<script>")
    expect(html).to include("&lt;script&gt;")
  end
end
