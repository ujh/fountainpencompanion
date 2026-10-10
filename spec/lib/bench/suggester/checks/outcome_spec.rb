require_relative "../bench_helper"

RSpec.describe Bench::Suggester::Checks::Outcome do
  it "classifies results" do
    expect(described_class.call({ "pen" => 1, "ink" => 2, "message" => "x" })).to eq("suggestion")
    expect(described_class.call({ pen: 1, ink: 2, error: "ToolCallLimitExceeded" })).to eq(
      "suggestion"
    )
    expect(described_class.call({ "message" => "x", "precheck" => "no_uninked_pens" })).to eq(
      "precheck"
    )
    expect(described_class.call({ "message" => "x", "error" => "DecisionNotReachedError" })).to eq(
      "error"
    )
    expect(described_class.call({ "message" => "x", "status" => "error" })).to eq("error")
    expect(described_class.call({ "message" => PenAndInkSuggester::ERROR_MESSAGE })).to eq("error")
    expect(described_class.call({ "message" => "You have reached your daily limit" })).to eq(
      "message_only"
    )
    expect(described_class.call(nil)).to eq("message_only")
  end
end
