require "rails_helper"

RSpec.describe PenAndInkSuggestion::Selection do
  let(:user) { create(:user) }
  let(:pens) { create_list(:collected_pen, 2, user:) }
  let(:inks) { create_list(:collected_ink, 3, user:) }
  let(:selection) { described_class.new(pens:, inks:, pen_total: 5, ink_total: 9) }

  describe "refs" do
    it "numbers pens P1… and inks I1… in list order" do
      expect(pens.map { |pen| selection.pen_ref(pen) }).to eq(%w[P1 P2])
      expect(inks.map { |ink| selection.ink_ref(ink) }).to eq(%w[I1 I2 I3])
    end

    it "resolves refs, ignoring case and surrounding space" do
      expect(selection.pen_for("P2")).to eq(pens[1])
      expect(selection.pen_for(" p1 ")).to eq(pens[0])
      expect(selection.ink_for("I3")).to eq(inks[2])
    end

    it "resolves only refs of its own side within the list" do
      expect(selection.pen_for("I1")).to be_nil
      expect(selection.ink_for("P1")).to be_nil
      expect(selection.pen_for("P3")).to be_nil
      expect(selection.pen_for("P0")).to be_nil
      expect(selection.pen_for(pens[0].id.to_s)).to be_nil
      expect(selection.pen_for(nil)).to be_nil
    end

    it "lists the shown ids" do
      expect(selection.shown_pen_ids).to eq(pens.map(&:id))
      expect(selection.shown_ink_ids).to eq(inks.map(&:id))
    end
  end

  describe "name cross-check" do
    let(:pens) do
      [
        create(:collected_pen, user:, brand: "Lamy", model: "Safari", color: "Pink", nib: "F"),
        create(:collected_pen, user:, brand: "Lamy", model: "Safari", color: "Blue", nib: "F")
      ]
    end
    let(:inks) do
      [
        create(:collected_ink, user:, brand_name: "Diamine", ink_name: "Damson"),
        create(:collected_ink, user:, brand_name: "Diamine", ink_name: "Oxblood")
      ]
    end

    it "finds a shown item that fits the name better than the chosen one" do
      expect(selection.better_named_pen(pens[1], "Lamy Safari, Pink")).to eq(pens[0])
      expect(selection.better_named_ink(inks[0], "Diamine Oxblood")).to eq(inks[1])
    end

    it "accepts the chosen item when it fits at least as well as any other" do
      expect(selection.better_named_pen(pens[0], "Lamy Safari, Pink")).to be_nil
      expect(selection.better_named_pen(pens[0], "Lamy Safari")).to be_nil
      expect(selection.better_named_ink(inks[1], "oxblood")).to be_nil
      expect(selection.better_named_ink(inks[1], nil)).to be_nil
    end

    it "builds the pen name shown in rows" do
      pen =
        build(
          :collected_pen,
          brand: "Lamy",
          model: "2000",
          color: "Black",
          material: "",
          trim_color: nil
        )

      expect(selection.pen_display_name(pen)).to eq("Lamy 2000, Black")
    end
  end

  describe "#violation_for" do
    it "allows a shown pen and ink" do
      expect(selection.violation_for(pen: pens[0], ink: inks[0])).to be_nil
    end

    it "rejects items that were not shown" do
      other_pen = create(:collected_pen, user:)
      other_ink = create(:collected_ink, user:)

      expect(selection.violation_for(pen: other_pen, ink: inks[0])).to include(
        "not a pen from PENS"
      )
      expect(selection.violation_for(pen: pens[0], ink: other_ink)).to include(
        "not an ink from INKS"
      )
    end

    it "rejects a swab" do
      swab = create(:collected_ink, user:, kind: "swab")
      selection = described_class.new(pens:, inks: [swab], pen_total: 2, ink_total: 1)

      expect(selection.violation_for(pen: pens[0], ink: swab)).to include("swab")
    end

    it "rejects a cartridge ink in a piston pen" do
      piston = create(:collected_pen, user:, brand: "TWSBI", model: "Eco", filling_system: "piston")
      cartridge = create(:collected_ink, user:, kind: "cartridge", ink_name: "Blue")
      selection = described_class.new(pens: [piston], inks: [cartridge], pen_total: 1, ink_total: 1)

      expect(selection.violation_for(pen: piston, ink: cartridge)).to eq(
        "Diamine Blue is a cartridge ink and TWSBI Eco takes no cartridges; " \
          "choose a different pen or ink."
      )
    end
  end

  it "is ended only with an end reason" do
    expect(selection).not_to be_ended
    expect(
      described_class.new(pens:, inks:, pen_total: 2, ink_total: 3, end_reason: :all_pairs_rejected)
    ).to be_ended
  end

  describe "pins" do
    it "knows which shown items were named" do
      pinned =
        described_class.new(
          pens:,
          inks:,
          pen_total: 2,
          ink_total: 3,
          pinned_pens: [pens[0]],
          pinned_inks: [inks[1]]
        )

      expect(pinned.pinned?(pens[0])).to be(true)
      expect(pinned.pinned?(inks[1])).to be(true)
      expect(pinned.pinned?(pens[1])).to be(false)
      expect(selection).not_to be_unfiltered
    end
  end
end
