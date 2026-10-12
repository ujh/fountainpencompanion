require "rails_helper"

RSpec.describe PenAndInkSuggestion::NameHints do
  let(:user) { create(:user) }

  def hints_for(text)
    snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user)
    index = PenAndInkSuggestion::NameIndex.for(snapshot)
    mentions = PenAndInkSuggestion::MentionMatcher.call(index, text)
    described_class.call(snapshot, mentions, index:)
  end

  def mention(text, side)
    PenAndInkSuggestion::MentionMatcher::Mention.new(text:, side:)
  end

  def pen(brand, model, **attributes)
    create(:collected_pen, user:, brand:, model:, **attributes)
  end

  def ink(brand, name, line: "", **attributes)
    create(:collected_ink, user:, brand_name: brand, line_name: line, ink_name: name, **attributes)
  end

  it "names the side and the text of a pen named in full" do
    pen("Corvid", "Halcyon Slim Asymmetry")

    expect(hints_for("Pick me an ink for the Corvid Halcyon Slim Asymmetry")).to eq(
      ["pen: Corvid Halcyon Slim Asymmetry"]
    )
  end

  it "adds the collection item when the request names it differently" do
    pen("Corvid", "Halcyon Slim Asymmetry")
    ink("Quillworth", "Harbour Fog", line: "Coastal")

    expect(hints_for("an ink for the Halcyon Slim Asymmetry")).to eq(
      ["pen: Halcyon Slim Asymmetry (Corvid Halcyon Slim Asymmetry)"]
    )
    expect(hints_for("something like coastal harbor fog")).to eq(
      ["ink: coastal harbor fog (Quillworth Coastal Harbour Fog)"]
    )
  end

  it "lists at most two collection items for one name" do
    pen("Corvid", "Halcyon")
    pen("Corvid", "Halcyon Mini")
    pen("Corvid", "Halcyon Slim")

    expect(hints_for("my Halcyon please").sole).to match(
      %r{\Apen: Halcyon \(Corvid Halcyon[^/]* / Corvid Halcyon[^/]*\)\z}
    )
  end

  it "marks a brand found without a model as a brand" do
    pen("Corvid", "Halcyon")
    pen("Corvid", "Kestrel")
    snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user)
    index = PenAndInkSuggestion::NameIndex.for(snapshot)

    expect(described_class.call(snapshot, [mention("Corvid", :pen)], index:)).to eq(
      ["pen brand: Corvid"]
    )
  end

  it "gives one line per side when a bare name fits a pen and an ink" do
    pen("Corvid", "Dandelion")
    ink("Quillworth", "Dandelion")

    expect(hints_for("Dandelion")).to contain_exactly(
      "pen: Dandelion (Corvid Dandelion)",
      "ink: Dandelion (Quillworth Dandelion)"
    )
  end

  it "leaves out names that only come close, that aren't found or can't be suggested" do
    pen("Corvid", "V126")
    pen("Corvid", "Rollerball One", nib: "Rollerball")
    snapshot = PenAndInkSuggestion::CollectionSnapshot.new(user)
    index = PenAndInkSuggestion::NameIndex.for(snapshot)
    mentions = [
      mention("Corvid V128", :pen),
      mention("Wrenfield Comet", :pen),
      mention("Corvid Rollerball One", :pen)
    ]

    expect(described_class.call(snapshot, mentions, index:)).to eq([])
  end

  it "names the usable item when its twin can't be suggested" do
    pen("Corvid", "Halcyon")
    pen("Corvid", "Halcyon", nib: "Rollerball")
    ink("Quillworth", "Harbour Fog")
    ink("Quillworth", "Harbour Fog", kind: "swab")

    expect(hints_for("Corvid Halcyon")).to eq(["pen: Corvid Halcyon"])
    expect(hints_for("Quillworth Harbour Fog")).to eq(["ink: Quillworth Harbour Fog"])
  end

  it "gives nothing when the request names nothing in the collection" do
    pen("Corvid", "Halcyon")

    expect(hints_for("something blue and a fine nib")).to eq([])
  end

  it "lists a name once when the request repeats it" do
    pen("Corvid", "Halcyon Slim")

    expect(hints_for("Halcyon Slim, yes the Halcyon Slim")).to eq(
      ["pen: Halcyon Slim (Corvid Halcyon Slim)"]
    )
  end
end
