require_relative "bench_helper"

RSpec.describe Bench::Suggester::JudgeScores do
  let(:key) do
    { "1" => { "A" => "v2", "B" => "baseline" }, "2" => { "A" => "baseline", "B" => "v2" } }
  end

  def grade(honoured, score)
    {
      "honoured" => honoured,
      "rationale" => score,
      "soft_wishes" => score,
      "concise" => score,
      "notes_accurate" => score,
      "comment" => ""
    }
  end

  it "unblinds and averages the grades per system" do
    grades = {
      "1" => {
        "A" => grade("yes", 5),
        "B" => grade("no", 2)
      },
      "2" => {
        "A" => grade("partial", 3),
        "B" => grade("yes", 4)
      }
    }

    expect(described_class.new(grades:, key:).by_system).to eq(
      "baseline" => {
        "graded" => 2,
        "honoured" => {
          "yes" => 0,
          "partial" => 1,
          "no" => 1
        },
        "honoured_yes_rate" => 0.0,
        "rationale" => 2.5,
        "soft_wishes" => 2.5,
        "concise" => 2.5,
        "notes_accurate" => 2.5
      },
      "v2" => {
        "graded" => 2,
        "honoured" => {
          "yes" => 2,
          "partial" => 0,
          "no" => 0
        },
        "honoured_yes_rate" => 1.0,
        "rationale" => 4.5,
        "soft_wishes" => 4.5,
        "concise" => 4.5,
        "notes_accurate" => 4.5
      }
    )
  end

  it "skips answers not graded yet" do
    grades = { "1" => { "A" => grade("yes", 5), "B" => grade(nil, nil) } }

    expect(described_class.new(grades:, key:).by_system.keys).to eq(["v2"])
  end

  it "rejects grades outside the rubric or the key" do
    expect {
      described_class.new(grades: { "1" => { "A" => grade("maybe", 3) } }, key:).by_system
    }.to raise_error(described_class::Invalid, /honoured/)
    expect {
      described_class.new(grades: { "1" => { "A" => grade("yes", 6) } }, key:).by_system
    }.to raise_error(described_class::Invalid, /rationale/)
    expect {
      described_class.new(grades: { "9" => { "A" => grade("yes", 3) } }, key:).by_system
    }.to raise_error(described_class::Invalid, /not in the key/)
    expect {
      described_class.new(grades: { "1" => { "C" => grade("yes", 3) } }, key:).by_system
    }.to raise_error(described_class::Invalid, /no answer C/)
  end
end
