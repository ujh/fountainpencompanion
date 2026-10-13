require "rails_helper"

RSpec.describe PenAndInkSuggester::RecordSuggestion do
  let(:user) { create(:user) }
  let(:pen) { create(:collected_pen, user:, filling_system: "piston") }
  let(:other_pen) { create(:collected_pen, user:, filling_system: "") }
  let(:ink) { create(:collected_ink, user:) }
  let(:other_ink) { create(:collected_ink, user:) }
  let(:pens) { [pen, other_pen] }
  let(:inks) { [ink, other_ink] }
  let(:selection) do
    PenAndInkSuggestion::Selection.new(pens:, inks:, pen_total: pens.size, ink_total: inks.size)
  end
  let(:rejected_pairs) { [] }
  let(:tool) { described_class.new(selection, rejected_pairs) }

  def record(pen_ref: "P1", ink_ref: "I1", reasoning: "A fine pairing.")
    tool.call(pen_ref:, ink_ref:, reasoning:)
  end

  it "is called record_suggestion and takes refs and reasoning" do
    expect(tool.name).to eq("record_suggestion")
    expect(tool.parameters.keys).to eq(%i[pen_ref pen_name ink_ref ink_name reasoning])
  end

  it "records the shown pen and ink and halts" do
    result = record(pen_ref: "P2", ink_ref: "I2", reasoning: "Lovely.")

    expect(result).to be_a(RubyLLM::Tool::Halt)
    expect(result.content).to eq("Suggestion recorded")
    expect(tool.result).to eq(pen: other_pen, ink: other_ink, reasoning: "Lovely.")
  end

  it "rejects an unknown ref" do
    expect(record(pen_ref: "P9")).to eq("P9 is not valid for pen_ref; use a P ref from PENS.")
    expect(record(ink_ref: "I9")).to eq("I9 is not valid for ink_ref; use an I ref from INKS.")
    expect(record(pen_ref: " ")).to eq(
      "A blank ref is not valid for pen_ref; use a P ref from PENS."
    )
    expect(tool.result).to be_nil
  end

  it "rejects a pen ref in the ink field and an ink ref in the pen field" do
    expect(record(ink_ref: "P1")).to eq("P1 is not valid for ink_ref; use an I ref from INKS.")
    expect(record(pen_ref: "I1")).to eq("I1 is not valid for pen_ref; use a P ref from PENS.")
  end

  it "rejects a database id" do
    expect(record(pen_ref: pen.id.to_s)).to include("not valid for pen_ref")
  end

  context "with a rejected pair" do
    let(:rejected_pairs) { [{ "pen_id" => pen.id, "ink_id" => ink.id }] }

    it "blocks the exact pairing" do
      expect(record(pen_ref: "P1", ink_ref: "I1")).to eq(
        "That exact pairing was rejected; choose a different pen or ink."
      )
    end

    it "still allows its pen and its ink in other pairings" do
      expect(record(pen_ref: "P1", ink_ref: "I2")).to be_a(RubyLLM::Tool::Halt)
      expect(
        described_class.new(selection, rejected_pairs).call(
          pen_ref: "P2",
          ink_ref: "I1",
          reasoning: "Fine."
        )
      ).to be_a(RubyLLM::Tool::Halt)
    end
  end

  context "with a swab or a cartridge in a piston pen among the rows" do
    let(:ink) { create(:collected_ink, user:, kind: "swab") }
    let(:other_ink) { create(:collected_ink, user:, kind: "cartridge") }

    it "rejects them and keeps the violation" do
      expect(record(ink_ref: "I1")).to include("swab")
      expect(record(ink_ref: "I2")).to include("takes no cartridges")
      expect(tool.violations.size).to eq(2)
      expect(tool.result).to be_nil
    end

    it "allows the cartridge in a pen without a filling system" do
      expect(record(pen_ref: "P2", ink_ref: "I2")).to be_a(RubyLLM::Tool::Halt)
      expect(tool.violations).to be_empty
    end
  end

  describe "name cross-check" do
    let(:pen) do
      create(:collected_pen, user:, brand: "Pilot", model: "Metropolitan", color: "Grey")
    end
    let(:other_pen) { create(:collected_pen, user:, brand: "LAMY", model: "Safari", color: "Pink") }
    let(:ink) { create(:collected_ink, user:, brand_name: "Diamine", ink_name: "Damson") }
    let(:other_ink) { create(:collected_ink, user:, brand_name: "KWZ", ink_name: "Cherry") }

    def record_named(pen_name:, ink_name:, pen_ref: "P1", ink_ref: "I1")
      tool.call(pen_ref:, pen_name:, ink_ref:, ink_name:, reasoning: "Fine.")
    end

    it "accepts names that fit the refs, however they are written" do
      expect(record_named(pen_name: "pilot metropolitan", ink_name: "Damson")).to be_a(
        RubyLLM::Tool::Halt
      )
    end

    it "rejects a pen name that fits another shown pen better" do
      expect(record_named(pen_name: "LAMY Safari, Pink", ink_name: "Diamine Damson")).to eq(
        "P1 is Pilot Metropolitan, Grey, plastic, gold, but pen_name says LAMY Safari, Pink, " \
          "which fits P2 better. Call record_suggestion again with the ref and name of the same row."
      )
      expect(tool.result).to be_nil
    end

    it "rejects an ink name that fits another shown ink better" do
      expect(record_named(pen_name: "Pilot Metropolitan", ink_name: "KWZ Cherry")).to start_with(
        "I1 is Diamine Damson, but ink_name says KWZ Cherry, which fits I2 better."
      )
    end

    it "accepts names that fit no shown item, and missing names" do
      expect(record_named(pen_name: "Something else", ink_name: "")).to be_a(RubyLLM::Tool::Halt)
      expect(
        described_class.new(selection, []).call(pen_ref: "P2", ink_ref: "I2", reasoning: "Ok")
      ).to be_a(RubyLLM::Tool::Halt)
    end
  end

  it "rejects blank reasoning" do
    expect(record(reasoning: " ")).to eq("Reasoning is blank.")
  end

  it "keeps the first valid suggestion" do
    record(pen_ref: "P1", ink_ref: "I1", reasoning: "First")
    result = record(pen_ref: "P2", ink_ref: "I2", reasoning: "Second")
    invalid = record(pen_ref: "P9", ink_ref: "I9", reasoning: "Third")

    expect(result.content).to eq("Suggestion already recorded")
    expect(invalid.content).to eq("Suggestion already recorded")
    expect(tool.result).to eq(pen:, ink:, reasoning: "First")
  end
end
