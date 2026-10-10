require_relative "bench_helper"

RSpec.describe Bench::Suggester::CartridgeCompatibility do
  def compatible?(filling, kind: "cartridge")
    described_class.compatible?(
      build(:collected_pen, filling_system: filling),
      build(:collected_ink, kind:)
    )
  end

  it "pairs cartridge inks with cartridge/converter pens and pens without a filling" do
    [
      "C/C",
      "c / c",
      "CC",
      "Cartridge/Converter",
      "converter",
      "International short",
      "standard long",
      "",
      nil
    ].each { |filling| expect(compatible?(filling)).to be(true), filling.inspect }
  end

  it "never pairs cartridge inks with other filling systems" do
    [
      "piston filler",
      "Vacuum",
      "eyedropper",
      "lever",
      "button filler",
      "sac",
      "Accurate"
    ].each { |filling| expect(compatible?(filling)).to be(false), filling.inspect }
  end

  it "pairs every other ink kind with any pen" do
    %w[bottle sample swab].each { |kind| expect(compatible?("piston filler", kind:)).to be(true) }
    expect(compatible?("piston filler", kind: nil)).to be(true)
  end
end
