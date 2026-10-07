require "rails_helper"

describe NormalizeCollectedInkColors do
  def ink_with_color(color)
    create(:collected_ink).tap { |ink| ink.update_column(:color, color) }
  end

  it "adds the missing # to bare hex colors" do
    ink = ink_with_color("A5D337")
    described_class.new.perform
    expect(ink.reload.read_attribute(:color)).to eq("#A5D337")
  end

  it "converts named colors to hex" do
    ink = ink_with_color(" Black")
    described_class.new.perform
    expect(ink.reload.read_attribute(:color)).to eq("#000000")
  end

  it "clears colors that cannot be repaired" do
    ink = ink_with_color("#9f6t")
    described_class.new.perform
    expect(ink.reload.read_attribute(:color)).to eq("")
  end

  it "leaves valid colors alone" do
    ink = ink_with_color("#ABCDEF")
    described_class.new.perform
    expect(ink.reload.read_attribute(:color)).to eq("#ABCDEF")
  end
end
