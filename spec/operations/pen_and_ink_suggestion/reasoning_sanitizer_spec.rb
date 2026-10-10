require "rails_helper"

RSpec.describe PenAndInkSuggestion::ReasoningSanitizer do
  def sanitize(text) = described_class.call(text)

  it "keeps plain markdown" do
    text = "The **wet** nib suits this _shading_ ink.\n\n- Smooth\n- Bold"

    expect(sanitize(text)).to eq(text)
  end

  it "reduces inline and reference links to their text" do
    text = "See [this ink](https://example.com/ink) and [that one][1].\n\n[1]: https://example.com"

    expect(sanitize(text)).to eq("See this ink and that one.")
  end

  it "removes inline and reference images" do
    text = "Look ![swab](https://example.com/a.png) here ![x][img]."

    expect(sanitize(text)).to eq("Look  here .")
  end

  it "removes raw HTML tags but keeps their text" do
    text = 'A <a href="https://evil.example">great</a> <b>pick</b>.<img src=x onerror=alert(1)>'

    expect(sanitize(text)).to eq("A great pick.")
  end

  it "removes script and style blocks with their content and HTML comments" do
    text = "Nice<script>alert(1)</script><style>p{}</style><!-- hidden --> pairing."

    expect(sanitize(text)).to eq("Nice pairing.")
  end

  it "removes autolinks and bare URLs" do
    text = "Buy at <https://shop.example> or https://shop.example/x or www.shop.example today."

    expect(sanitize(text)).to eq("Buy at  or  or  today.")
  end

  it "turns headings into plain lines" do
    expect(sanitize("## Why it works\nThe nib is broad.")).to eq("Why it works\nThe nib is broad.")
  end

  it "removes the server's width classes" do
    text =
      "Its fine (W3) nib and EF nib (W2) suit it. A very fine nib (UEF, W1), the fine W3 nib, " \
        "a W4-W6 range and W4+ nibs."

    expect(sanitize(text)).to eq(
      "Its fine nib and EF nib suit it. A very fine nib (UEF), the fine nib, a range and nibs."
    )
  end

  it "collapses extra blank lines and trims whitespace" do
    expect(sanitize("  One.  \n\n\n\nTwo.  ")).to eq("One.\n\nTwo.")
  end

  it "treats nil as blank" do
    expect(sanitize(nil)).to eq("")
  end
end
