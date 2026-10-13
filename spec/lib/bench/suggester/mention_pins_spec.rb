require_relative "bench_helper"

RSpec.describe Bench::Suggester::MentionPins do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let!(:lamy) do
    create(:collected_pen, user:, brand: "Lamy", model: "2000", created_at: as_of - 1.year)
  end
  let!(:kakuno) do
    create(:collected_pen, user:, brand: "Pilot", model: "Kakuno", created_at: as_of - 1.year)
  end
  let!(:oxblood) do
    create(
      :collected_ink,
      user:,
      brand_name: "Diamine",
      ink_name: "Oxblood",
      created_at: as_of - 1.year
    )
  end

  def bench_case(id, instruction)
    Bench::Suggester::BenchCase.new(
      id:,
      log_id: id.to_i,
      user_id: user.id,
      as_of:,
      source: instruction ? "instruction" : "plain",
      split: "dev",
      tier: "free",
      instruction:,
      rejected_pairs: [],
      original: {
      },
      fidelity: {
      }
    )
  end

  def label(id, named_pens: [], named_inks: [], reviewed: false)
    Bench::Suggester::Label.from_h(
      id,
      { "named_pens" => named_pens, "named_inks" => named_inks, "reviewed" => reviewed }
    )
  end

  it "counts strings with a pin the label does not name" do
    cases = [
      bench_case("1", "Lamy 2000 please"),
      bench_case("2", "Diamine Oxblood in any pen"),
      bench_case("3", "something red"),
      bench_case("4", nil)
    ]
    labels = {
      "1" => label("1", named_pens: [lamy.id]),
      "2" => label("2"),
      "3" => label("3"),
      "4" => label("4")
    }

    summary = described_class.new(cases:, labels:).summary

    expect(summary).to include(
      "strings" => 3,
      "pinned" => 2,
      "with_false_pin" => 1,
      "false_pin_rate" => 0.3333,
      "gate" => 0.02,
      "pins" => 2,
      "false_pins" => 1,
      "named" => 1,
      "named_hit" => 1,
      "named_hit_rate" => 1.0
    )
  end

  it "reads the collection as at the time of the run" do
    create(:collected_pen, user:, brand: "Lamy", model: "Safari", created_at: as_of + 1.day)
    cases = [bench_case("1", "Lamy Safari please"), bench_case("2", "Lamy 2000 please")]
    labels = { "1" => label("1"), "2" => label("2") }

    rows = described_class.new(cases:, labels:).rows

    expect(rows.map { |row| row["pins"] }).to eq([[], [["pen", lamy.id]]])
  end

  it "reports the reviewed labels on their own" do
    cases = [bench_case("1", "Pilot Kakuno"), bench_case("2", "Lamy 2000")]
    labels = { "1" => label("1", named_pens: [kakuno.id], reviewed: true), "2" => label("2") }

    summary = described_class.new(cases:, labels:).summary

    expect(summary["reviewed"]).to include(
      "strings" => 1,
      "with_false_pin" => 0,
      "false_pin_rate" => 0.0
    )
    expect(summary["with_false_pin"]).to eq(1)
  end

  it "reports each split on its own" do
    cases = [bench_case("1", "Lamy 2000"), bench_case("2", "Lamy 2000").with(split: "test")]
    labels = { "1" => label("1", named_pens: [lamy.id]), "2" => label("2") }

    by_split = described_class.new(cases:, labels:).summary["by_split"]

    expect(by_split.keys).to eq(%w[dev test])
    expect(by_split["dev"]).to include("strings" => 1, "with_false_pin" => 0)
    expect(by_split["test"]).to include("strings" => 1, "with_false_pin" => 1)
  end

  it "skips cases without a label or whose user is gone" do
    cases = [bench_case("1", "Lamy 2000"), bench_case("2", "Lamy 2000").with(user_id: 0)]

    expect(described_class.new(cases:, labels: { "2" => label("2") }).rows).to be_empty
  end
end
