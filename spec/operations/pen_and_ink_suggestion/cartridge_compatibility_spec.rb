require "rails_helper"

RSpec.describe PenAndInkSuggestion::CartridgeCompatibility do
  def compatible?(filling_system, kind: "cartridge")
    described_class.compatible?(
      build(:collected_pen, filling_system:),
      build(:collected_ink, kind:)
    )
  end

  it "pairs a cartridge ink with cartridge/converter pens" do
    [
      "C/C",
      "cc",
      "Converter",
      "cartridge",
      "International short",
      "standard long"
    ].each { |filling| expect(compatible?(filling)).to be(true), filling }
  end

  it "pairs a cartridge ink with a pen without a filling system" do
    expect(compatible?("")).to be(true)
    expect(compatible?("  ")).to be(true)
  end

  it "keeps a cartridge ink out of pens with another filling system" do
    %w[piston vacuum eyedropper lever button].each do |filling|
      expect(compatible?(filling)).to be(false), filling
    end
  end

  it "pairs every other ink kind with any pen" do
    expect(compatible?("piston", kind: "bottle")).to be(true)
    expect(compatible?("piston", kind: "sample")).to be(true)
    expect(compatible?("piston", kind: nil)).to be(true)
  end
end
