require_relative "bench_helper"

RSpec.describe Bench::Suggester::Checker do
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let(:snapshot) { PenAndInkSuggestion::CollectionSnapshot.new(user, as_of:) }
  let!(:pen) { create(:collected_pen, user:, created_at: as_of - 1.day) }
  let!(:ink) { create(:collected_ink, user:, created_at: as_of - 1.day, kind: "sample") }
  let(:label) do
    Bench::Suggester::Label.from_h(
      1,
      "named_pens" => [pen.id],
      "constraints" => {
        "ink" => {
          "kinds_include" => ["sample"]
        }
      }
    )
  end

  it "runs every check on a suggestion" do
    result =
      described_class.new(
        snapshot:,
        extra_data: {
          "pen" => pen.id,
          "ink" => ink.id,
          "message" => "## Novelty"
        },
        label:
      ).call

    expect(result).to include("outcome" => "suggestion", "hard_failure" => false)
    expect(result["validity"]).to include("valid" => true)
    expect(result["leakage"]).to include("leaked" => true, "headings" => true)
    expect(result["novelty"]).to include("ink_novel" => true)
    expect(result["named"]).to eq("pen_hit" => true, "ink_hit" => nil)
    expect(result["constraints"]).to eq("hard" => { "ink.kinds_include" => "met" }, "soft" => {})
    expect(result["label_unknown_ids"]).to eq({})
  end

  it "runs only the outcome and label checks without a suggestion" do
    result =
      described_class.new(
        snapshot:,
        extra_data: {
          "message" => PenAndInkSuggester::ERROR_MESSAGE
        },
        label:
      ).call

    expect(result).to include(
      "outcome" => "error",
      "hard_failure" => true,
      "validity" => nil,
      "leakage" => nil,
      "novelty" => nil,
      "named" => {
        "pen_hit" => false,
        "ink_hit" => nil
      },
      "constraints" => {
        "hard" => {
          "ink.kinds_include" => "no_suggestion"
        },
        "soft" => {
        }
      }
    )
  end

  it "skips the label checks without a label" do
    result = described_class.new(snapshot:, extra_data: { pen: pen.id, ink: ink.id }).call

    expect(result).to include("named" => nil, "constraints" => nil, "label_unknown_ids" => nil)
    expect(result["validity"]["valid"]).to be(true)
  end
end
