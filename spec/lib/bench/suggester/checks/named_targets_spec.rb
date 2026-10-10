require_relative "../bench_helper"

RSpec.describe Bench::Suggester::Checks::NamedTargets do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let(:snapshot) { PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:) }
  let!(:pen) { create(:collected_pen, user:, created_at: as_of - 1.day) }
  let!(:other_pen) { create(:collected_pen, user:, created_at: as_of - 1.day) }
  let!(:ink) { create(:collected_ink, user:, created_at: as_of - 1.day) }
  let!(:other_ink) { create(:collected_ink, user:, created_at: as_of - 1.day) }

  def check(label, extra_data)
    described_class.new(
      snapshot:,
      label: Bench::Suggester::Label.from_h(1, label),
      extra_data:
    ).call
  end

  it "hits when the pick is one of the labelled targets" do
    result =
      check(
        { "named_pens" => [pen.id, other_pen.id], "named_inks" => [ink.id] },
        { "pen" => other_pen.id, "ink" => other_ink.id }
      )

    expect(result).to eq("pen_hit" => true, "ink_hit" => false)
  end

  it "misses when there is no pick" do
    expect(check({ "named_pens" => [pen.id] }, { "message" => "Sorry" })).to eq(
      "pen_hit" => false,
      "ink_hit" => nil
    )
  end

  it "is nil for a side without targets" do
    expect(check({}, { "pen" => pen.id, "ink" => ink.id })).to eq(
      "pen_hit" => nil,
      "ink_hit" => nil
    )
  end

  it "scores only the targets owned at the time of the request" do
    later = create(:collected_pen, user:, created_at: as_of + 1.day)
    someone_elses = create(:collected_ink, created_at: as_of - 1.day)

    expect(
      check(
        { "named_pens" => [later.id], "named_inks" => [someone_elses.id, ink.id] },
        { "pen" => later.id, "ink" => ink.id }
      )
    ).to eq("pen_hit" => nil, "ink_hit" => true)
  end
end
