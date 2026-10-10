require_relative "../bench_helper"

RSpec.describe Bench::Suggester::Checks::Novelty do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let(:today) { as_of.to_date }
  let(:snapshot) { PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:) }
  let(:pen) { create(:collected_pen, user:, created_at: as_of - 1.year) }
  let(:ink) { create(:collected_ink, user:, created_at: as_of - 1.year, color: "#1E3A8A") }

  def check = described_class.new(snapshot:, extra_data: { "pen" => pen.id, "ink" => ink.id }).call

  def ink_it(pen, ink, inked_on:, archived_on: nil)
    create(
      :currently_inked,
      user:,
      collected_pen: pen,
      collected_ink: ink,
      inked_on:,
      archived_on:,
      created_at: inked_on.to_time
    )
  end

  it "counts never-used items as novel" do
    expect(check).to include("pen_novel" => true, "ink_novel" => true)
  end

  it "counts items unused for 180 days at the time of the run as novel" do
    other_pen = create(:collected_pen, user:, created_at: as_of - 2.years)
    other_ink = create(:collected_ink, user:, created_at: as_of - 2.years)
    ink_it(pen, other_ink, inked_on: today - 300, archived_on: today - 180)
    ink_it(other_pen, ink, inked_on: today - 300, archived_on: today - 179)

    expect(check).to include("pen_novel" => true, "ink_novel" => false)
  end

  it "ignores inkings made after the run" do
    other_pen = create(:collected_pen, user:, created_at: as_of - 2.years)
    ink_it(other_pen, ink, inked_on: today + 1)

    expect(check).to include("ink_novel" => true)
  end

  it "says whether the ink's colour family is new against the inks inked at the time" do
    inked_pen = create(:collected_pen, user:, created_at: as_of - 2.years)
    blue = create(:collected_ink, user:, created_at: as_of - 2.years, color: "#1D4ED8")
    red = create(:collected_ink, user:, created_at: as_of - 2.years, color: "#B91C1C")
    inking = ink_it(inked_pen, red, inked_on: today - 10)

    expect(check["colour_new_vs_inked"]).to be(true)

    inking.update!(collected_ink: blue)
    expect(
      described_class.new(
        snapshot: PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:),
        extra_data: {
          "pen" => pen.id,
          "ink" => ink.id
        }
      ).call[
        "colour_new_vs_inked"
      ]
    ).to be(false)
  end

  it "has no colour verdict for an ink without a colour" do
    ink.update_column(:color, "")

    expect(check["colour_new_vs_inked"]).to be_nil
  end
end
