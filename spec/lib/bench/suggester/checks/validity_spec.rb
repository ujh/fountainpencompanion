require_relative "../bench_helper"

RSpec.describe Bench::Suggester::Checks::Validity do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let(:snapshot) { PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:) }
  let!(:pen) { create(:collected_pen, user:, created_at: as_of - 1.day, filling_system: "piston") }
  let!(:ink) { create(:collected_ink, user:, created_at: as_of - 1.day) }

  def check(pen_id: pen.id, ink_id: ink.id, rejected_pairs: [], **extra)
    described_class.new(
      snapshot:,
      extra_data: {
        "pen" => pen_id,
        "ink" => ink_id,
        **extra
      },
      rejected_pairs:
    ).call
  end

  it "passes an owned, active, compatible, new pair" do
    expect(check).to eq(
      "pen_owned_active" => true,
      "ink_owned_active" => true,
      "pen_fountain" => true,
      "ink_not_swab" => true,
      "cartridge_compatible" => true,
      "not_rejected_repeat" => true,
      "pen_uninked_or_flagged" => true,
      "valid" => true
    )
  end

  it "fails items of other users, items archived before the run and items added after it" do
    other = create(:collected_pen, created_at: as_of - 1.day)
    archived = create(:collected_ink, user:, created_at: as_of - 9.days, archived_on: as_of.to_date)
    later = create(:collected_pen, user:, created_at: as_of + 1.minute)

    expect(check(pen_id: other.id)).to include("pen_owned_active" => false, "valid" => false)
    expect(check(ink_id: archived.id)).to include("ink_owned_active" => false, "valid" => false)
    expect(check(pen_id: later.id)).to include("pen_owned_active" => false)
  end

  it "passes items archived after the run" do
    pen.update!(archived_on: as_of.to_date + 1)

    expect(check["valid"]).to be(true)
  end

  it "fails non-fountain pens, swabs and cartridge inks in piston pens" do
    ballpoint = create(:collected_pen, user:, created_at: as_of - 1.day, nib: "Ballpoint")
    swab = create(:collected_ink, user:, created_at: as_of - 1.day, kind: "swab")
    cartridge = create(:collected_ink, user:, created_at: as_of - 1.day, kind: "cartridge")

    expect(check(pen_id: ballpoint.id)).to include("pen_fountain" => false, "valid" => false)
    expect(check(ink_id: swab.id)).to include("ink_not_swab" => false, "valid" => false)
    expect(check(ink_id: cartridge.id)).to include(
      "cartridge_compatible" => false,
      "valid" => false
    )
  end

  it "fails an exact rejected repeat but not a pair sharing one item" do
    other_ink = create(:collected_ink, user:, created_at: as_of - 1.day)
    rejected_pairs = [{ "pen_id" => pen.id, "ink_id" => ink.id }]

    expect(check(rejected_pairs:)).to include("not_rejected_repeat" => false, "valid" => false)
    expect(check(ink_id: other_ink.id, rejected_pairs:)).to include("valid" => true)
  end

  it "fails a pen inked at the time unless the result flags it" do
    create(
      :currently_inked,
      user:,
      collected_pen: pen,
      inked_on: as_of.to_date - 3,
      created_at: as_of - 3.days
    )

    expect(check).to include("pen_uninked_or_flagged" => false, "valid" => false)
    expect(check("pen_currently_inked" => true)).to include("valid" => true)
  end
end
