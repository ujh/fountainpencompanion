require_relative "bench_helper"

RSpec.describe Bench::Suggester::ExtractorRunner do
  include ConstraintExtractorHelpers

  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

  def label(text, previous_suggestion: false)
    Bench::Suggester::ExtractorLabel.from_h({ "text" => text, previous_suggestion: })
  end

  def stub_extraction(model: "gpt-4.1-mini-2025-04-14")
    stub_request(:post, openai_url).to_return do |request|
      text = JSON.parse(request.body)["messages"].last["content"]
      arguments = text.include?("samples") ? { ink: { kinds_include: ["sample"] } } : {}
      {
        status: 200,
        body: set_constraints_completion(arguments, model:).to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      }
    end
  end

  it "records each label's constraints, usage, cost and latency, and leaves no logs behind" do
    stub_extraction
    runner = described_class.new(labels: [label("only samples"), label("anything")])

    results = runner.run

    expect(results.keys).to eq(["only samples", "anything"])
    expect(results["only samples"]).to include(
      "constraints" =>
        PenAndInkSuggestion::Constraints.from_h(ink: { kinds_include: ["sample"] }).to_h,
      "error" => nil,
      "usage" => include("model" => "gpt-4.1-mini-2025-04-14", "prompt_tokens" => 1_000)
    )
    expect(results["only samples"]["cost_usd"]).to be_within(1e-9).of(
      (1_000 * 0.40 + 100 * 1.60) / 1e6
    )
    expect(results["only samples"]["latency_ms"]).to be_a(Integer)
    expect(runner.spent_usd).to be_within(1e-9).of(2 * (1_000 * 0.40 + 100 * 1.60) / 1e6)
    expect(runner.stop_reason).to be_nil
    expect(AgentLog.count).to eq(0)
  end

  it "records the error of a failed extraction" do
    stub_request(:post, openai_url).to_return(
      status: 500,
      body: { error: { message: "down" } }.to_json,
      headers: {
        "Content-Type" => "application/json"
      }
    )

    result = described_class.new(labels: [label("anything")]).run.fetch("anything")

    expect(result).to include("constraints" => nil, "error" => "RubyLLM::ServerError")
  end

  it "passes whether a suggestion was turned down" do
    stub_extraction
    allow(PenAndInkConstraintExtractor).to receive(:new).and_call_original

    described_class.new(labels: [label("same pen", previous_suggestion: true)]).run

    expect(PenAndInkConstraintExtractor).to have_received(:new).with(
      "same pen",
      parent_agent_log: kind_of(AgentLog),
      previous_suggestion: true
    )
  end

  it "uses another model when asked, under the extractor's log name" do
    stub_extraction(model: "gpt-4.1-2025-04-14")
    names = []
    allow(AgentLog).to receive(:new).and_wrap_original do |original, *arguments, &block|
      original.call(*arguments, &block).tap { |log| names << log.name }
    end

    result = described_class.new(labels: [label("anything")], model: "gpt-4.1").run["anything"]

    expect(WebMock).to have_requested(:post, openai_url).with(
      body: hash_including("model" => "gpt-4.1")
    )
    expect(result["cost_usd"]).to be_within(1e-9).of((1_000 * 2.0 + 100 * 8.0) / 1e6)
    expect(names).to include(PenAndInkConstraintExtractor.name)
  end

  it "stops once the budget is spent" do
    stub_extraction
    runner = described_class.new(labels: [label("one"), label("two")], max_usd: 0.0001)

    results = runner.run

    expect(results.keys).to eq(["one"])
    expect(runner.stop_reason).to eq(described_class::BUDGET)
  end

  it "stops when a model has no price" do
    stub_extraction(model: "gpt-unpriced")
    runner = described_class.new(labels: [label("one"), label("two")])

    results = runner.run

    expect(results.keys).to eq(["one"])
    expect(runner.stop_reason).to eq(described_class::UNPRICED)
  end
end
