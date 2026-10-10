require_relative "bench_helper"

RSpec.describe Bench::Suggester::InstructionHonoured do
  let(:key) do
    {
      "1" => {
        "A" => "v2",
        "B" => "baseline"
      },
      "2" => {
        "A" => "baseline",
        "B" => "v2"
      },
      "3" => {
        "A" => "v2",
        "B" => "baseline"
      }
    }
  end

  def grade(honoured)
    {
      "honoured" => honoured,
      "rationale" => 4,
      "soft_wishes" => 4,
      "concise" => 4,
      "notes_accurate" => 4,
      "comment" => ""
    }
  end

  def checks(hard: {}, valid: true, named: nil, hard_failure: false)
    {
      "outcome" => hard_failure ? "error" : "suggestion",
      "hard_failure" => hard_failure,
      "validity" => (hard_failure ? nil : { "valid" => valid }),
      "named" => named,
      "constraints" => {
        "hard" => hard,
        "soft" => {
        }
      }
    }
  end

  def row(case_id, source: "instruction", reviewed: false, label: true, **check_options)
    {
      "case_id" => case_id,
      "split" => "test",
      "source" => source,
      "label" => (label ? { "reviewed" => reviewed, "corrected" => false } : nil),
      "checks" => checks(**check_options)
    }
  end

  def honoured(grades, checks)
    judge_scores = Bench::Suggester::JudgeScores.new(grades:, key:)
    described_class.new(judge_scores:, checks:).by_system
  end

  it "counts a case only when every hard check passes and the judge says yes" do
    grades = {
      "1" => {
        "A" => grade("yes"),
        "B" => grade("yes")
      },
      "2" => {
        "A" => grade("yes"),
        "B" => grade("partial")
      },
      "3" => {
        "A" => grade("yes"),
        "B" => grade("yes")
      }
    }
    checks = {
      "v2" => [
        row("1", reviewed: true, hard: { "ink.kinds_include" => "met", "pen.usage" => "relaxed" }),
        row("2", hard: { "ink.kinds_include" => "met" }),
        row("3", hard: { "ink.kinds_include" => "unsatisfiable" })
      ],
      "baseline" => [
        row("1", reviewed: true, hard: { "ink.kinds_include" => "violated" }),
        row("2", named: { "pen_hit" => false, "ink_hit" => nil }),
        row("3", valid: false)
      ]
    }

    expect(honoured(grades, checks)).to eq(
      "baseline" => {
        "graded_without_checks" => 0,
        "graded_without_label" => 0,
        "all_labels" => {
          "cases" => 3,
          "honoured" => 0,
          "rate" => 0.0
        },
        "reviewed_labels" => {
          "cases" => 1,
          "honoured" => 0,
          "rate" => 0.0
        }
      },
      "v2" => {
        "graded_without_checks" => 0,
        "graded_without_label" => 0,
        "all_labels" => {
          "cases" => 3,
          "honoured" => 1,
          "rate" => 0.3333
        },
        "reviewed_labels" => {
          "cases" => 1,
          "honoured" => 1,
          "rate" => 1.0
        }
      }
    )
  end

  it "fails a hard failure and a run without a suggestion for a hard field" do
    grades = { "1" => { "A" => grade("yes"), "B" => grade("yes") } }
    checks = {
      "v2" => [row("1", hard_failure: true)],
      "baseline" => [row("1", hard: { "ink.kinds_include" => "no_suggestion" })]
    }

    result = honoured(grades, checks)

    expect(result.transform_values { |values| values["all_labels"]["honoured"] }).to eq(
      "baseline" => 0,
      "v2" => 0
    )
  end

  it "leaves out runs without an instruction and counts graded cases it can't score" do
    grades = {
      "1" => {
        "A" => grade("yes")
      },
      "2" => {
        "B" => grade("yes")
      },
      "3" => {
        "A" => grade("yes")
      }
    }
    checks = { "v2" => [row("1", source: "plain"), row("2", label: false)] }

    expect(honoured(grades, checks)["v2"]).to eq(
      "graded_without_checks" => 1,
      "graded_without_label" => 1,
      "all_labels" => {
        "cases" => 0,
        "honoured" => 0,
        "rate" => nil
      },
      "reviewed_labels" => {
        "cases" => 0,
        "honoured" => 0,
        "rate" => nil
      }
    )
  end
end
