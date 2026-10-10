require "rails_helper"

RSpec.describe PenAndInkSuggestion::SuggestionMessage do
  let(:pen) do
    build(
      :collected_pen,
      brand: "Pilot",
      model: "Custom 74",
      color: "Smoke",
      material: "",
      trim_color: "",
      nib: "M"
    )
  end
  let(:ink) { build(:collected_ink, brand_name: "Pilot", ink_name: "Kon-peki", kind: "bottle") }

  def message(pen: self.pen, ink: self.ink, reasoning: "A calm blue.", notes: [])
    nib_profile = NibProfile.parse(pen.nib, brand: pen.brand, model: pen.model)
    described_class.new(pen:, ink:, nib_profile:, reasoning:, notes:).to_s
  end

  it "puts the pen and ink names from the database above the reasoning" do
    expect(message).to eq(
      "- **Pen:** Pilot Custom 74, Smoke, M\n- **Ink:** Pilot Kon-peki - bottle\n\nA calm blue."
    )
  end

  it "adds the nib label when the pen's nib is blank" do
    pen = build(:collected_pen, brand: "Ahab", model: "Flex", nib: "", color: "", material: "")

    expect(message(pen:)).to start_with("- **Pen:** Ahab Flex, gold · flex (model name) → W3 flex")
  end

  it "leaves the nib label out for a pen without any nib information" do
    pen = build(:collected_pen, brand: "Lamy", model: "Safari", nib: "", color: "", material: "")

    expect(message(pen:)).to start_with("- **Pen:** Lamy Safari, gold\n")
  end

  it "escapes markdown in item names" do
    ink = build(:collected_ink, brand_name: "Ink*Co", ink_name: "[Blue]_one", kind: "")

    expect(message(ink:)).to include("- **Ink:** Ink\\*Co \\[Blue\\]\\_one\n")
  end

  it "puts server notes in italics between the header and the reasoning" do
    expect(message(notes: ["One combination at a time."])).to eq(
      "- **Pen:** Pilot Custom 74, Smoke, M\n- **Ink:** Pilot Kon-peki - bottle\n\n" \
        "_One combination at a time._\n\nA calm blue."
    )
  end
end
