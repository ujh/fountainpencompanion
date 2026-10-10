require_relative "bench_helper"

RSpec.describe Bench::Suggester::Runner do
  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }
  let(:user) { create(:user) }
  let(:as_of) { Time.zone.parse("2026-05-01 10:00") }
  let!(:pen) do
    create(:collected_pen, user:, created_at: as_of - 1.year, brand: "Pilot", model: "Kakuno")
  end
  let!(:ink) { create(:collected_ink, user:, created_at: as_of - 1.year, ink_name: "Blue Velvet") }
  let!(:later_pen) do
    create(:collected_pen, user:, created_at: as_of + 1.day, model: "Bought later")
  end

  def bench_case(id: "1", instruction: "Something blue", tier: "free", rejected_pairs: [])
    Bench::Suggester::BenchCase.new(
      id:,
      log_id: id.to_i,
      user_id: user.id,
      as_of:,
      source: instruction ? "instruction" : "plain",
      split: "dev",
      tier:,
      instruction:,
      rejected_pairs:,
      original: {
      },
      fidelity: {
      }
    )
  end

  def completion(model: "gpt-4.1-mini-2025-04-14", pen_id: pen.id, ink_id: ink.id)
    arguments = { suggestion: "Ink the Kakuno with Blue Velvet.", ink_id:, pen_id: }.to_json
    {
      "model" => model,
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              {
                "id" => "call_1",
                "type" => "function",
                "function" => {
                  "name" => "record_suggestion",
                  "arguments" => arguments
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => {
        "prompt_tokens" => 6_000,
        "completion_tokens" => 150,
        "total_tokens" => 6_150
      }
    }
  end

  def stub_completion(body = completion)
    stub_request(:post, openai_url).to_return(
      status: 200,
      body: body.to_json,
      headers: {
        "Content-Type" => "application/json"
      }
    )
  end

  def user_prompt(request)
    JSON.parse(request.body)["messages"].find { |message| message["role"] == "user" }["content"]
  end

  it "replays a case through today's suggester and records the result" do
    stub_completion

    result = described_class.new(cases: [bench_case]).run.fetch("1")

    expect(result["extra_data"]).to include(
      "pen" => pen.id,
      "ink" => ink.id,
      "message" => "Ink the Kakuno with Blue Velvet."
    )
    expect(result["cost_usd"]).to be_within(1e-9).of((6_000 * 0.40 + 150 * 1.60) / 1e6)
    expect(result["usages"].sole).to include(
      "model" => "gpt-4.1-mini-2025-04-14",
      "prompt_tokens" => 6_000
    )
    expect(result["latency_ms"]).to be_a(Integer)
    expect(result["prompt_chars"]).to be_positive
  end

  it "replays the collection, the instruction and the rejected pairs as at the time of the run" do
    stub_completion
    rejected_pairs = [{ "ink_id" => ink.id, "pen_id" => 0 }]
    other_ink = create(:collected_ink, user:, created_at: as_of - 1.year)
    create(
      :currently_inked,
      user:,
      collected_pen: create(:collected_pen, user:, created_at: as_of - 1.year),
      collected_ink: other_ink,
      inked_on: as_of.to_date - 40,
      archived_on: as_of.to_date - 3,
      created_at: as_of - 40.days
    )

    described_class.new(cases: [bench_case(rejected_pairs:)]).run

    expect(WebMock).to(
      have_requested(:post, openai_url).with do |request|
        prompt = user_prompt(request)
        prompt.include?(pen.id.to_s) && !prompt.include?(later_pen.id.to_s) &&
          prompt.include?("about 1 month") && prompt.include?("Something blue") &&
          prompt.include?(JSON.generate(rejected_pairs))
      end
    )
  end

  it "cuts the instruction to the widget's limit" do
    stub_completion

    described_class.new(cases: [bench_case(instruction: "#{"a" * 500}TAIL")]).run

    expect(WebMock).to have_requested(:post, openai_url).with { |request|
      user_prompt(request).exclude?("TAIL")
    }
  end

  it "uses the tier recorded for the case" do
    user.update!(patron: true)
    stub_completion(completion(model: "gpt-4.1-mini-2025-04-14"))

    described_class.new(cases: [bench_case(tier: "free")]).run

    expect(WebMock).to have_requested(:post, openai_url).with(
      body: hash_including("model" => "gpt-4.1-mini")
    )
  end

  it "uses the premium model for a premium case" do
    stub_completion(completion(model: "gpt-4.1-2025-04-14"))

    result = described_class.new(cases: [bench_case(tier: "premium")]).run.fetch("1")

    expect(WebMock).to have_requested(:post, openai_url).with(
      body: hash_including("model" => "gpt-4.1")
    )
    expect(result["cost_usd"]).to be_within(1e-9).of((6_000 * 2.0 + 150 * 8.0) / 1e6)
  end

  it "bypasses the daily cap" do
    create_list(:agent_log, 20, name: PenAndInkSuggester.name, owner: user, created_at: as_of)
    stub_completion

    result = described_class.new(cases: [bench_case]).run.fetch("1")

    expect(result["extra_data"]["pen"]).to eq(pen.id)
  end

  it "leaves no trace in the database" do
    stub_completion

    expect { described_class.new(cases: [bench_case]).run }.not_to(
      change { [AgentLog.count, user.collected_pens.count] }
    )
  end

  it "seeds the row order per case" do
    create_list(:collected_pen, 30, user:, created_at: as_of - 1.day)
    prompts = []
    stub_request(:post, openai_url).to_return do |request|
      prompts << user_prompt(request)
      { status: 200, body: completion.to_json, headers: { "Content-Type" => "application/json" } }
    end

    described_class.new(cases: [bench_case], seed: 1).run
    described_class.new(cases: [bench_case], seed: 1).run
    described_class.new(cases: [bench_case], seed: 2).run

    expect(prompts[0]).to eq(prompts[1])
    expect(prompts[2]).not_to eq(prompts[0])
  end

  it "records an API failure as an error result and goes on" do
    stub_completion
    stub_request(:post, openai_url)
      .with { |request| request.body.include?("FAIL") }
      .to_return(
        status: 500,
        body: { error: { message: "down" } }.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

    results =
      described_class.new(
        cases: [bench_case(id: "1", instruction: "FAIL"), bench_case(id: "2")]
      ).run

    expect(results["1"]["extra_data"]).to eq(
      "message" => PenAndInkSuggester::ERROR_MESSAGE,
      "status" => "error",
      "error" => "RubyLLM::ServerError"
    )
    expect(results["2"]["extra_data"]["pen"]).to eq(pen.id)
  end

  it "stops once the budget is spent" do
    stub_completion
    cases = [bench_case(id: "1"), bench_case(id: "2")]

    runner = described_class.new(cases:, max_usd: 0.001)
    results = runner.run

    expect(results.keys).to eq(["1"])
    expect(runner.spent_usd).to be > 0.001
    expect(WebMock).to have_requested(:post, openai_url).once
  end

  it "skips a case whose user is gone" do
    missing = bench_case.with(user_id: 0)

    expect(described_class.new(cases: [missing]).run).to eq({})
  end

  it "yields each result" do
    stub_completion
    yielded = []

    described_class
      .new(cases: [bench_case])
      .run { |run_case, result| yielded << [run_case.id, result["extra_data"]["pen"]] }

    expect(yielded).to eq([["1", pen.id]])
  end
end
