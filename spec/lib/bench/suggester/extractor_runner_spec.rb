require_relative "bench_helper"

RSpec.describe Bench::Suggester::ExtractorRunner do
  include ConstraintExtractorHelpers

  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

  def label(text, previous_suggestion: false, **context)
    Bench::Suggester::ExtractorLabel.from_h(
      { "text" => text, previous_suggestion:, **context.stringify_keys }
    )
  end

  def extractor_message
    content = nil
    expect(WebMock).to have_requested(:post, openai_url)
      .with { |request|
        content = JSON.parse(request.body)["messages"].last["content"]
        true
      }
      .once
    content
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
      previous_suggestion: true,
      names_found: []
    )
  end

  describe "names found in the collection" do
    let(:user) { create(:user) }
    let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
    let(:text) { "an ink for the Halcyon Slim" }

    before do
      create(
        :collected_pen,
        user:,
        brand: "Corvid",
        model: "Halcyon Slim",
        created_at: as_of - 1.day
      )
      create(:collected_pen, user:, brand: "Corvid", model: "Kestrel", created_at: as_of + 1.day)
      stub_extraction
    end

    it "sends the names production would find in the collection as it was then" do
      result =
        described_class
          .new(labels: [label("#{text} or the Kestrel", user_id: user.id, as_of: as_of.iso8601)])
          .run
          .values
          .sole

      expect(extractor_message).to end_with(
        "<names_found>\npen: Halcyon Slim (Corvid Halcyon Slim)\n</names_found>"
      )
      expect(result["names_found"]).to eq(["pen: Halcyon Slim (Corvid Halcyon Slim)"])
    end

    it "sends no names without a collection, for a deleted user or when switched off" do
      labels = [label(text), label("#{text} please", user_id: 0, as_of: as_of.iso8601)]
      described_class.new(labels:).run
      described_class.new(
        labels: [label(text, user_id: user.id, as_of: as_of.iso8601)],
        names_found: false
      ).run

      messages = []
      expect(WebMock).to have_requested(:post, openai_url)
        .with { |request|
          messages << JSON.parse(request.body)["messages"].last["content"]
          true
        }
        .times(3)
      expect(messages).to all(match(%r{\A<request>[^<]*</request>\z}))
    end
  end

  it "sends what the production extractor sends when asked for its model" do
    stub_extraction(model: "gpt-6-luna-2026-09-22")

    described_class.new(labels: [label("anything")], model: "gpt-6-luna").run

    expect(WebMock).to have_requested(:post, openai_url).with { |request|
      body = JSON.parse(request.body)
      body["model"] == "gpt-6-luna" && body["temperature"] == 0 &&
        body["reasoning_effort"] == "none"
    }
  end

  it "uses another model when asked, under the extractor's log name" do
    stub_extraction(model: "gpt-4.1-2025-04-14")
    names = []
    allow(AgentLog).to receive(:new).and_wrap_original do |original, *arguments, &block|
      original.call(*arguments, &block).tap { |log| names << log.name }
    end

    result = described_class.new(labels: [label("anything")], model: "gpt-4.1").run["anything"]

    expect(WebMock).to have_requested(:post, openai_url).with { |request|
      body = JSON.parse(request.body)
      body["model"] == "gpt-4.1" && body["temperature"] == 0 && !body.key?("reasoning_effort")
    }
    expect(result["cost_usd"]).to be_within(1e-9).of((1_000 * 2.0 + 100 * 8.0) / 1e6)
    expect(names).to include(PenAndInkConstraintExtractor.name)
  end

  describe "reasoning models" do
    after { RubyLLM.models.all.reject! { |model| model.id.start_with?("gpt-9-") } }

    def requested_body
      body = nil
      expect(WebMock).to have_requested(:post, openai_url)
        .with { |request|
          body = JSON.parse(request.body)
          true
        }
        .once
      body
    end

    it "sends the lowest reasoning effort, with the temperature RubyLLM allows at effort none" do
      stub_extraction(model: "gpt-5.4-nano-2026-03-17")
      runner = described_class.new(labels: [label("only samples")], model: "gpt-5.4-nano")

      result = runner.run["only samples"]

      expect(requested_body).to include(
        "model" => "gpt-5.4-nano",
        "reasoning_effort" => "none",
        "temperature" => 1.0
      )
      expect(result["constraints"]).to eq(
        PenAndInkSuggestion::Constraints.from_h(ink: { kinds_include: ["sample"] }).to_h
      )
      expect(result["cost_usd"]).to be_within(1e-12).of((1_000 * 0.20 + 100 * 1.25) / 1e6)
      expect(runner.model_settings.reasoning_effort).to eq("none")
    end

    it "sends the reasoning effort asked for" do
      stub_extraction(model: "gpt-5-mini-2025-08-07")

      described_class.new(
        labels: [label("anything")],
        model: "gpt-5-mini",
        reasoning_effort: "low"
      ).run

      expect(requested_body).to include("reasoning_effort" => "low")
      expect(requested_body).not_to have_key("temperature")
    end

    it "runs a model the RubyLLM registry does not know yet" do
      stub_extraction(model: "gpt-9-test")
      runner = described_class.new(labels: [label("one"), label("two")], model: "gpt-9-test")

      results = runner.run

      expect(requested_body).to include(
        "model" => "gpt-9-test",
        "reasoning_effort" => "none",
        "temperature" => 0
      )
      expect(results["one"]["error"]).to be_nil
      expect(runner.stop_reason).to eq(described_class::UNPRICED)
    end
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
