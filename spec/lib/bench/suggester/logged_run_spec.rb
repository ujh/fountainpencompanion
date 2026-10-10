require_relative "bench_helper"

RSpec.describe Bench::Suggester::LoggedRun do
  let(:user) { create(:user) }

  def run_for(**options)
    described_class.new(suggester_log(user:, **options))
  end

  describe "#instruction" do
    it "reads the instruction from the prompt" do
      run = run_for(instruction: "Only samples\nplease", rejected: [{ ink_id: 1, pen_id: 2 }])

      expect(run.instruction).to eq("Only samples\nplease")
    end

    it "is nil without an instruction" do
      expect(run_for.instruction).to be_nil
    end

    it "keeps text that only looks like the rejected list" do
      text =
        "Not this\n\nThe following suggestions were rejected. Do not recommend them again:\nnone"

      expect(run_for(instruction: text).instruction).to eq(text)
    end

    it "normalises case and whitespace for grouping" do
      expect(run_for(instruction: "  Not a   PARKER ").normalised_instruction).to eq("not a parker")
    end
  end

  describe "#rejected_pairs" do
    it "keeps only pairs with integer ids, the newest 50" do
      pairs = (1..55).map { |id| { ink_id: id, pen_id: id } }
      run = run_for(rejected: [{}, { ink_id: "1", pen_id: 2 }, *pairs])

      expect(run.rejected_pairs.size).to eq(50)
      expect(run.rejected_pairs.first).to eq({ "ink_id" => 6, "pen_id" => 6 })
    end

    it "is empty without a rejected list" do
      expect(run_for(instruction: "Blue").rejected_pairs).to eq([])
    end

    it "prefers the logged pairs over the prompt" do
      run =
        run_for(
          rejected: [{ ink_id: 1, pen_id: 2 }],
          extra_data: {
            "rejected_pairs" => [
              { "ink_id" => 3, "pen_id" => 4 },
              { "ink_id" => "5", "pen_id" => 6 }
            ]
          }
        )

      expect(run.rejected_pairs).to eq([{ "ink_id" => 3, "pen_id" => 4 }])
    end

    it "is empty when the run logged no pairs" do
      run = run_for(rejected: [{ ink_id: 1, pen_id: 2 }], extra_data: { "rejected_pairs" => [] })

      expect(run.rejected_pairs).to eq([])
    end
  end

  describe "shown ids" do
    it "reads the pen and ink ids from the CSV sections" do
      run = run_for(pen_ids: [3, 1], ink_ids: [7, 9])

      expect(run.shown_pen_ids).to eq([3, 1])
      expect(run.shown_ink_ids).to eq([7, 9])
    end

    it "is empty when the prompt listed no pens" do
      expect(run_for(ink_ids: [7]).shown_pen_ids).to eq([])
    end

    it "prefers the logged ids over the prompt" do
      run =
        run_for(
          pen_ids: [3],
          ink_ids: [7],
          extra_data: {
            "shown_pen_ids" => [5, "x"],
            "shown_ink_ids" => [8]
          }
        )

      expect(run.shown_pen_ids).to eq([5])
      expect(run.shown_ink_ids).to eq([8])
    end
  end

  it "reads the user messages of a raix-era transcript" do
    log =
      create(
        :agent_log,
        name: "PenAndInkSuggester",
        owner: user,
        transcript: [
          { "user" => suggester_prompt(pen_ids: [4], ink_ids: [5]) },
          {
            "user" => "IMPORTANT: Take extra care to follow these additional instructions:\nGreen"
          },
          { "assistant" => "Done" },
          { "user" => "You must make a decision" }
        ]
      )

    run = described_class.new(log)

    expect(run.instruction).to eq("Green")
    expect(run.shown_pen_ids).to eq([4])
    expect(run).to be_llm_run
  end

  it "stops reading the prompt at a nested list of tool messages" do
    log =
      create(
        :agent_log,
        name: "PenAndInkSuggester",
        owner: user,
        transcript: [
          { "user" => suggester_prompt(pen_ids: [4], ink_ids: [5]) },
          [
            { "role" => "assistant", "content" => nil, "tool_calls" => [] },
            {
              "role" => "user",
              "content" =>
                "IMPORTANT: Take extra care to follow these additional instructions:\nRed"
            }
          ],
          { "user" => "IMPORTANT: Take extra care to follow these additional instructions:\nBlue" }
        ]
      )

    run = described_class.new(log)

    expect(run.shown_pen_ids).to eq([4])
    expect(run.instruction).to be_nil
    expect(run).to be_llm_run
  end

  it "is not an LLM run without a prompt or for a precheck" do
    no_prompt = create(:agent_log, name: "PenAndInkSuggester", owner: user, transcript: [])
    precheck =
      suggester_log(user:, extra_data: { "message" => "x", "precheck" => "no_uninked_pens" })

    expect(described_class.new(no_prompt)).not_to be_llm_run
    expect(described_class.new(precheck)).not_to be_llm_run
  end

  it "derives the tier from the logged model" do
    expect(run_for(model: "gpt-4.1-mini-2025-04-14").tier).to eq("free")
    expect(run_for(model: "gpt-4.1-2025-04-14").tier).to eq("premium")
    expect(run_for(model: "other").tier).to be_nil
  end

  it "parses the CSV prompt the legacy path writes" do
    pen = create(:collected_pen, user:, brand: "Pilot", model: "Custom 74")
    ink = create(:collected_ink, user:, brand_name: "Sailor", ink_name: "Jentle")
    ink.update!(
      micro_cluster:
        create(
          :micro_cluster,
          macro_cluster: create(:macro_cluster, description: "Wet.\n\nShading, \"lovely\".")
        )
    )
    arguments = { suggestion: "Try it", ink_id: ink.id, pen_id: pen.id }.to_json
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json"
      },
      body: {
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
          "prompt_tokens" => 10,
          "completion_tokens" => 5,
          "total_tokens" => 15
        },
        "model" => "gpt-4.1-mini-2025-04-14"
      }.to_json
    )
    suggester =
      Bench::Suggester::BaselineSuggester.new(
        user,
        "Something wet",
        [{ "ink_id" => 8, "pen_id" => 9 }],
        as_of: Time.current,
        legacy: true
      )
    suggester.perform

    run = described_class.new(suggester.agent_log.reload)

    expect(run.instruction).to eq("Something wet")
    expect(run.rejected_pairs).to eq([{ "ink_id" => 8, "pen_id" => 9 }])
    expect(run.shown_pen_ids).to eq([pen.id])
    expect(run.shown_ink_ids).to eq([ink.id])
    expect(run.original).to include("pen_id" => pen.id, "ink_id" => ink.id, "message" => "Try it")
    expect(run.tier).to eq("free")
  end

  it "reads the instruction, rejected pairs and shown rows of an instruction run" do
    pen = create(:collected_pen, user:)
    ink = create(:collected_ink, user:, kind: "bottle")
    arguments = { pen_ref: "P1", ink_ref: "I1", reasoning: "Fine." }.to_json
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json"
      },
      body: {
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
          "prompt_tokens" => 10,
          "completion_tokens" => 5,
          "total_tokens" => 15
        },
        "model" => "gpt-4.1-mini-2025-04-14"
      }.to_json
    )
    rejected = [{ "ink_id" => 8, "pen_id" => 9 }]
    suggester = PenAndInkSuggester.new(user, "Something   wet\nand dark", rejected)
    suggester.perform

    run = described_class.new(suggester.agent_log.reload)

    expect(run.instruction).to eq("Something wet and dark")
    expect(run.rejected_pairs).to eq(rejected)
    expect(run.shown_pen_ids).to eq([pen.id])
    expect(run.shown_ink_ids).to eq([ink.id])
    expect(run).to be_llm_run
  end

  it "reads the rejected pairs and shown rows of a run without an instruction" do
    pen = create(:collected_pen, user:)
    ink = create(:collected_ink, user:, kind: "bottle")
    arguments = { pen_ref: "P1", ink_ref: "I1", reasoning: "Fine." }.to_json
    stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
      status: 200,
      headers: {
        "Content-Type" => "application/json"
      },
      body: {
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
          "prompt_tokens" => 10,
          "completion_tokens" => 5,
          "total_tokens" => 15
        },
        "model" => "gpt-4.1-mini-2025-04-14"
      }.to_json
    )
    rejected = [{ "ink_id" => 8, "pen_id" => 9 }, { "ink_id" => 10, "pen_id" => 11 }]
    suggester = PenAndInkSuggester.new(user, nil, rejected)
    suggester.perform

    run = described_class.new(suggester.agent_log.reload)

    expect(run.instruction).to be_nil
    expect(run.rejected_pairs).to eq(rejected)
    expect(run.shown_pen_ids).to eq([pen.id])
    expect(run.shown_ink_ids).to eq([ink.id])
    expect(run.original).to include("pen_id" => pen.id, "ink_id" => ink.id)
    expect(run).to be_llm_run
  end
end
