require_relative "bench_helper"

RSpec.describe Bench::Suggester::GradingExport do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let!(:pen) do
    create(
      :collected_pen,
      user:,
      created_at: as_of - 1.year,
      brand: "Sailor",
      model: "Pro Gear",
      nib: "MF"
    )
  end
  let!(:ink) do
    create(
      :collected_ink,
      user:,
      created_at: as_of - 1.year,
      ink_name: "Oku-yama",
      color: "#8B1A3A",
      tags_as_string: "shimmer"
    )
  end

  def bench_case(id)
    Bench::Suggester::BenchCase.new(
      id:,
      log_id: id.to_i,
      user_id: user.id,
      as_of:,
      source: "instruction",
      split: "test",
      tier: "free",
      instruction: "Something red",
      rejected_pairs: [{ "ink_id" => 1, "pen_id" => 2 }],
      original: {
      },
      fidelity: {
      }
    )
  end

  let(:cases) { (1..6).map { |id| bench_case(id.to_s) } }
  let(:runs) do
    {
      "v2" =>
        cases.to_h do |c|
          [
            c.id,
            {
              "extra_data" => {
                "pen" => pen.id,
                "ink" => ink.id,
                "message" => "V2 answer\nsecond line"
              }
            }
          ]
        end,
      "baseline" =>
        cases.first(5).to_h { |c| [c.id, { "extra_data" => { "message" => "Baseline answer" } }] }
    }
  end
  let(:labels) { { "1" => Bench::Suggester::Label.from_h(1, "notes" => "Red only") } }

  subject(:export) { described_class.new(cases:, runs:, labels:, seed: 3) }

  it "blinds the systems per case, the same way for a seed" do
    expect(export.key.keys).to eq(%w[1 2 3 4 5 6])
    expect(export.key.values).to all(
      satisfy { |systems| systems.keys == %w[A B] && systems.values.sort == %w[baseline v2] }
    )
    expect(export.key.values.map { |systems| systems["A"] }.uniq.size).to eq(2)
    expect(described_class.new(cases:, runs:, labels:, seed: 3).key).to eq(export.key)
  end

  it "writes the answers with the items they name, without system names" do
    markdown = export.files["grading.md"]

    expect(markdown).to include(
      "Request: Something red",
      "Rejected pairs before this run: 1",
      "Label notes: Red only"
    )
    expect(markdown).to include("Sailor Pro Gear", "MF → W3 (Japanese)", "piston filler")
    expect(markdown).to include("Diamine Oku-yama - bottle (bottle; red, dark; shimmer)")
    expect(markdown).to include(
      "> V2 answer\n> second line",
      "> Baseline answer",
      "(no result)",
      "- Pen: (none)"
    )
    expect(markdown).not_to include("baseline", "v2")
  end

  it "writes a key and an empty grades template" do
    files = export.files

    expect(JSON.parse(files["grading_key.json"])).to eq(export.key)
    expect(JSON.parse(files["grades_template.json"])["1"]["A"]).to eq(
      "honoured" => nil,
      "rationale" => nil,
      "soft_wishes" => nil,
      "concise" => nil,
      "notes_accurate" => nil,
      "comment" => ""
    )
  end
end
