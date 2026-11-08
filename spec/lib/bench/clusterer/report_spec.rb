require_relative "bench_helper"

RSpec.describe Bench::Clusterer::Report do
  let(:approve_case) { bench_case(id: "assign-1", expected: "approve") }
  let(:reject_case) { bench_case(id: "assign-2", expected: "reject", disputed: true) }

  def result(case_id, got, run: 0)
    { "case_id" => case_id, "run" => run, "got" => got }
  end

  subject(:report) do
    described_class.new(
      cases: [approve_case, reject_case],
      runs: {
        "master" => [
          result("assign-1", "reject"),
          result("assign-1", "reject", run: 1),
          result("assign-2", "reject"),
          result("assign-2", "error", run: 1)
        ],
        "current" => [
          result("assign-1", "approve"),
          result("assign-1", "approve", run: 1),
          result("assign-2", "approve"),
          result("assign-2", "reject", run: 1)
        ]
      }
    )
  end

  it "scores each kind and expected decision per run, keeping disputed cases apart" do
    expect(report.groups).to eq(
      "assign approve" => {
        "master" => {
          "correct" => 0,
          "scored" => 2,
          "unscored" => 0
        },
        "current" => {
          "correct" => 2,
          "scored" => 2,
          "unscored" => 0
        }
      },
      "assign reject (disputed)" => {
        "master" => {
          "correct" => 1,
          "scored" => 1,
          "unscored" => 1
        },
        "current" => {
          "correct" => 1,
          "scored" => 2,
          "unscored" => 0
        }
      }
    )
  end

  it "lists the cases whose rate changed between the first and the last run" do
    expect(report.changes).to eq(
      [
        {
          "case_id" => "assign-1",
          "expected" => "approve",
          "name" => "Pilot | Iroshizuku | Kon-peki",
          "before" => %w[reject reject],
          "after" => %w[approve approve],
          "better" => true
        },
        {
          "case_id" => "assign-2",
          "expected" => "reject",
          "name" => "Pilot | Iroshizuku | Kon-peki",
          "before" => %w[reject error],
          "after" => %w[approve reject],
          "better" => false
        }
      ]
    )
  end

  it "prints the scores and the changes" do
    text = report.to_text

    expect(text).to include("assign approve")
    expect(text).to include("master 0/2")
    expect(text).to include("master 1/1 (+1 unscored)")
    expect(text).to include("BETTER  assign-1")
    expect(text).to include("WORSE   assign-2")
  end

  it "lists no changes for a single run" do
    single = described_class.new(cases: [approve_case], runs: { "current" => [] })

    expect(single.changes).to eq([])
  end
end
