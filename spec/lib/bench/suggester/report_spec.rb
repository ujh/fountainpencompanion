require_relative "bench_helper"

RSpec.describe Bench::Suggester::Report do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let!(:pen) { create(:collected_pen, user:, created_at: as_of - 1.year) }
  let!(:ink) { create(:collected_ink, user:, created_at: as_of - 1.year) }
  let!(:sample) { create(:collected_ink, user:, created_at: as_of - 1.year, kind: "sample") }
  let!(:swab) { create(:collected_ink, user:, created_at: as_of - 1.year, kind: "swab") }

  def bench_case(id, source: "instruction", split: "dev")
    Bench::Suggester::BenchCase.new(
      id:,
      log_id: id.to_i,
      user_id: user.id,
      as_of:,
      source:,
      split:,
      tier: "free",
      instruction: source == "plain" ? nil : "Samples",
      rejected_pairs: [],
      original: {
      },
      fidelity: {
      }
    )
  end

  def label(reviewed: false)
    Bench::Suggester::Label.from_h(
      1,
      "named_inks" => [sample.id],
      "constraints" => {
        "ink" => {
          "kinds_include" => ["sample"]
        }
      },
      "reviewed" => reviewed
    )
  end

  let(:cases) do
    [
      bench_case("1"),
      bench_case("2"),
      bench_case("3", source: "plain", split: "test"),
      bench_case("4", source: "plain", split: "test")
    ]
  end
  let(:results) do
    {
      "1" => {
        "extra_data" => {
          "pen" => pen.id,
          "ink" => sample.id,
          "message" => "Fine"
        },
        "cost_usd" => 0.002,
        "latency_ms" => 1000
      },
      "2" => {
        "extra_data" => {
          "pen" => pen.id,
          "ink" => ink.id,
          "message" => "Balance of novelty"
        },
        "cost_usd" => 0.004,
        "latency_ms" => 3000
      },
      "3" => {
        "extra_data" => {
          "pen" => pen.id,
          "ink" => swab.id,
          "message" => "A swab"
        },
        "cost_usd" => 0.003,
        "latency_ms" => 2000
      },
      "4" => {
        "extra_data" => {
          "message" => PenAndInkSuggester::ERROR_MESSAGE,
          "status" => "error"
        },
        "cost_usd" => nil
      }
    }
  end

  subject(:report) { described_class.new(cases:, results:, labels: { "1" => label, "2" => label }) }

  it "summarises the label-free metrics" do
    summary = report.summary

    expect(summary).to include(
      "runs" => 4,
      "outcomes" => {
        "error" => 1,
        "suggestion" => 3
      },
      "hard_failure_rate" => 0.25,
      "suggestions" => 3,
      "valid_rate" => 0.6667,
      "validity_failures" => {
        "ink_not_swab" => 1
      },
      "swab_or_cartridge_violations" => 1,
      "rule_leakage_rate" => 0.3333,
      "cost" => {
        "runs_priced" => 3,
        "total_usd" => 0.009,
        "mean_usd" => 0.003
      },
      "latency_ms" => {
        "p50" => 2000,
        "p90" => 3000
      }
    )
    expect(summary["novelty"]).to eq(
      "runs" => 1,
      "ink_novel_share" => 1.0,
      "pen_novel_share" => 1.0,
      "colour_new_vs_inked_share" => 1.0
    )
  end

  it "summarises the label-based metrics" do
    summary = report.summary

    expect(summary["named_ink_hit"]).to eq("cases" => 2, "rate" => 0.5)
    expect(summary["named_pen_hit"]).to eq("cases" => 0, "rate" => nil)
    expect(summary["constraints"]).to eq(
      "cases" => 2,
      "scored_cases" => 2,
      "met_or_relaxed_rate" => 0.5,
      "cases_with_unsatisfiable" => 0,
      "fields" => {
        "ink.kinds_include" => {
          "met" => 1,
          "violated" => 1
        }
      }
    )
    expect(summary["labels"]).to eq("labelled" => 2, "reviewed" => 0)
  end

  it "summarises each split" do
    expect(report.summary_by_split.keys).to eq(%w[all dev test])
    expect(report.summary_by_split["test"]["runs"]).to eq(2)
  end

  it "skips cases without a result or a user" do
    gone = bench_case("5").with(user_id: 0)

    rows =
      described_class.new(
        cases: [*cases, gone, bench_case("6")],
        results: results.merge("5" => results["1"])
      ).rows

    expect(rows.map { |row| row["case_id"] }).to eq(%w[1 2 3 4])
  end

  it "says when label-based metrics rest on unreviewed draft labels" do
    expect(report.to_text).to include(
      "scored against unreviewed draft labels (0 of 2 reviewed by the owner)"
    )
    expect(report.to_text).to include("hard failures: 25.0%")

    reviewed = described_class.new(cases:, results:, labels: { "1" => label(reviewed: true) })
    expect(reviewed.to_text).to include("all 1 labels reviewed by the owner")
    expect(described_class.new(cases:, results:).to_text).to include("no labels")
  end

  describe ".for_logs" do
    it "checks live logs with their transcripts and sub-agent usage" do
      log =
        suggester_log(
          user:,
          created_at: as_of,
          instruction: "Blue",
          rejected: [{ ink_id: ink.id, pen_id: pen.id }],
          extra_data: {
            "pen" => pen.id,
            "ink" => ink.id,
            "message" => "Again"
          }
        )
      create(
        :agent_log,
        owner: log,
        usage: {
          "model" => "gpt-4.1-mini",
          "prompt_tokens" => 1000,
          "completion_tokens" => 0
        }
      )

      report = described_class.for_logs(AgentLog.where(id: log.id).includes(:agent_logs))

      expect(report.cases.sole).to have_attributes(
        source: "instruction",
        split: "online",
        instruction: "Blue"
      )
      expect(report.rows.sole["checks"]["validity"]).to include("not_rejected_repeat" => false)
      expect(report.rows.sole["cost_usd"]).to be_within(1e-9).of((2000 * 0.40 + 100 * 1.60) / 1e6)
    end
  end
end
