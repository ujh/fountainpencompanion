require_relative "../bench_helper"

RSpec.describe Bench::Suggester::Checks::RuleLeakage do
  def check(text) = described_class.new(text).call

  it "finds rule words" do
    result =
      check("A nice balance of Novelty and favourites. Its usage count is low; id 4. A favorite.")

    expect(result).to include(
      "terms" => ["balance", "favorite", "favourite", "id", "novelty", "usage count"],
      "leaked" => true
    )
  end

  it "does not treat words containing id as the id rule" do
    expect(check("An ideal, vivid ink with acidic notes")).to include(
      "terms" => [],
      "leaked" => false
    )
  end

  it "finds headings, links and images" do
    expect(check("### Suggestion\nText")).to include("headings" => true, "leaked" => true)
    expect(check("Text with a # sign")).to include("headings" => false)
    expect(check("See [the ink](https://example.com)")).to include(
      "links" => true,
      "leaked" => true
    )
    expect(check("![swab](swab.png)")).to include("links" => true)
    expect(check("Visit http://example.com")).to include("links" => true)
  end

  it "checks the reasoning when the result has one, else the message" do
    expect(
      described_class.for({ "message" => "## Header", "reasoning" => "Plain text" }).call["leaked"]
    ).to be(false)
    expect(described_class.for({ "message" => "## Header" }).call["leaked"]).to be(true)
  end
end
