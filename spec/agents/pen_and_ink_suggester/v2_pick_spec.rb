require "rails_helper"

RSpec.describe PenAndInkSuggester do
  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }
  let(:user) { create(:user) }
  let!(:pen) do
    create(:collected_pen, user:, brand: "Pilot", model: "Custom 74", color: "Smoke", nib: "M")
  end
  let!(:ink) do
    create(:collected_ink, user:, brand_name: "Pilot", ink_name: "Kon-peki", kind: "bottle")
  end

  def record_call(id = "call_1", pen_ref: "P1", ink_ref: "I1", reasoning: "A calm, wet blue.")
    {
      "id" => id,
      "type" => "function",
      "function" => {
        "name" => "record_suggestion",
        "arguments" => { pen_ref:, ink_ref:, reasoning: }.to_json
      }
    }
  end

  def completion(tool_calls: nil, content: "")
    message = { "role" => "assistant", "content" => content }
    message["tool_calls"] = tool_calls if tool_calls
    {
      "id" => "chatcmpl-1",
      "object" => "chat.completion",
      "model" => "gpt-4.1-mini",
      "choices" => [
        {
          "index" => 0,
          "message" => message,
          "finish_reason" => tool_calls ? "tool_calls" : "stop"
        }
      ],
      "usage" => {
        "prompt_tokens" => 10,
        "completion_tokens" => 5,
        "total_tokens" => 15
      }
    }
  end

  def stub_completions(*bodies)
    stub_request(:post, openai_url).to_return(
      *bodies.map do |body|
        { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
      end
    )
  end

  def stub_pick(**arguments)
    stub_completions(completion(tool_calls: [record_call(**arguments)]))
  end

  def requests
    bodies = []
    expect(WebMock).to have_requested(:post, openai_url)
      .with { |req|
        bodies << JSON.parse(req.body)
        true
      }
      .at_least_once
    bodies
  end

  def message_content(body, role)
    roles = role == "system" ? %w[system developer] : [role]
    body["messages"].find { |message| roles.include?(message["role"]) }["content"]
  end

  def capture_requests(body)
    captured = []
    stub_request(:post, openai_url).to_return do |request|
      captured << JSON.parse(request.body)
      { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
    end
    captured
  end

  describe "a run without an instruction" do
    it "sends the static rules and the nib reference as the system message" do
      stub_pick

      described_class.new(user).perform

      system_message = message_content(requests.first, "system")
      expect(system_message).to eq(PenAndInkSuggestion::PickPrompt::SYSTEM_DIRECTIVE)
      expect(system_message).to include("## Nib knowledge", "- W1 XXF", "record_suggestion")
    end

    it "sends refs and compact rows, but no database ids" do
      stub_pick

      described_class.new(user).perform

      user_message = message_content(requests.first, "user")
      expect(user_message).to include("PENS (1 of 1 uninked)\nP1 | Pilot Custom 74, Smoke")
      expect(user_message).to include("INKS (1 of 1)\nI1 | Pilot Kon-peki | bottle")
      expect(user_message).to include("CURRENTLY INKED (0)")
      expect(user_message).not_to match(/\b(#{pen.id}|#{ink.id})\b/)
    end

    it "offers the record_suggestion tool with refs and reasoning, one call at a time" do
      stub_pick

      described_class.new(user).perform

      body = requests.first
      function = body["tools"].sole["function"]
      expect(function["name"]).to eq("record_suggestion")
      expect(function["parameters"]["properties"].keys).to eq(
        %w[pen_ref pen_name ink_ref ink_name reasoning]
      )
      expect(body["parallel_tool_calls"]).to be(false)
      expect(body["tool_choice"]).to eq("required")
    end

    it "builds the message from the database names and the reasoning" do
      stub_pick(reasoning: "The **Pilot Prera** is great with this blue.")

      response = described_class.new(user).perform

      expect(response).to eq(
        message:
          "- **Pen:** Pilot Custom 74, Smoke, plastic, gold, M\n" \
            "- **Ink:** Pilot Kon-peki - bottle\n\n" \
            "The **Pilot Prera** is great with this blue.",
        ink: ink.id,
        pen: pen.id
      )
    end

    it "strips links, images and raw HTML from the reasoning before composing the message" do
      stub_pick(
        reasoning:
          "Try [this](https://evil.example) ![x](https://evil.example/x.png)<b>now</b>. " \
            "https://evil.example"
      )

      suggester = described_class.new(user)
      response = suggester.perform

      expect(response[:message]).to end_with("Try this now.")
      expect(suggester.agent_log.extra_data["reasoning"]).to eq("Try this now.")
    end

    it "logs what was shown and how it was chosen" do
      stub_pick
      suggester = described_class.new(user, nil, [], queue_ms: 12, seed: 99)

      suggester.perform

      expect(suggester.agent_log.extra_data).to include(
        "ink" => ink.id,
        "pen" => pen.id,
        "reasoning" => "A calm, wet blue.",
        "constraints" => nil,
        "constraints_source" => "none",
        "shown_pen_ids" => [pen.id],
        "shown_ink_ids" => [ink.id],
        "pins" => [],
        "notes" => [],
        "relaxations" => [],
        "seed" => 99,
        "queue_ms" => 12
      )
      expect(suggester.agent_log.extra_data["latency_ms"]).to be_a(Integer)
      expect(suggester.agent_log.state).to eq("waiting-for-approval")
    end

    it "returns only the result fields for the cache" do
      stub_pick

      expect(described_class.new(user).perform.keys).to eq(%i[message ink pen])
    end

    it "lets the model retry after a wrong ref" do
      stub_completions(
        completion(tool_calls: [record_call("call_1", pen_ref: "I1")]),
        completion(tool_calls: [record_call("call_2")])
      )

      response = described_class.new(user).perform

      expect(response[:pen]).to eq(pen.id)
      expect(WebMock).to have_requested(:post, openai_url).twice
      tool_message = requests.last["messages"].find { |message| message["role"] == "tool" }
      expect(tool_message["content"]).to eq("I1 is not valid for pen_ref; use a P ref from PENS.")
    end

    it "keeps the first valid call of a parallel response" do
      other_pen = create(:collected_pen, user:)
      stub_completions(
        completion(
          tool_calls: [
            record_call("call_1", pen_ref: "P9"),
            record_call("call_2", pen_ref: "P1", reasoning: "First"),
            record_call("call_3", pen_ref: "P2", reasoning: "Second")
          ]
        )
      )

      suggester = described_class.new(user, seed: 1)
      response = suggester.perform

      first_pen_id = suggester.agent_log.extra_data["shown_pen_ids"].first
      expect(response[:pen]).to eq(first_pen_id)
      expect([pen.id, other_pen.id]).to include(first_pen_id)
      expect(response[:message]).to end_with("First")
    end

    it "returns the error result with the shown rows when no decision is reached" do
      stub_completions(completion(content: "I pick the Pilot."))

      suggester = described_class.new(user, seed: 5)
      response = suggester.perform

      expect(response).to eq(described_class.error_result)
      expect(suggester.agent_log.extra_data).to include(
        "error" => "DecisionNotReachedError",
        "status" => "error",
        "shown_pen_ids" => [pen.id],
        "seed" => 5
      )
    end

    it "keeps the Patreon link in the out-of-requests message" do
      create_list(:agent_log, described_class::MAX_PER_DAY, name: described_class.name, owner: user)

      response = described_class.new(user).perform

      expect(response[:message]).to include("[Patron](https://www.patreon.com/bePatron?u=6900241)")
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "builds the same prompt for the same seed and another one for another seed" do
      create_list(:collected_pen, 40, user:)
      create_list(:collected_ink, 60, user:)
      captured = capture_requests(completion(tool_calls: [record_call]))

      [3, 3, 4].each { |seed| described_class.new(user, seed:).perform }

      prompts = captured.map { |body| message_content(body, "user") }
      expect(prompts[0]).to eq(prompts[1])
      expect(prompts[2]).not_to eq(prompts[0])
    end

    it "sends 25 pens and 40 inks to free users, 40 and 80 to patrons and 60 and 120 to admins" do
      create_list(:collected_pen, 60, user:)
      create_list(:collected_ink, 120, user:)
      captured = capture_requests(completion(tool_calls: [record_call]))

      described_class.new(user).perform
      user.update!(patron: true)
      described_class.new(user).perform
      user.update!(admin: true)
      described_class.new(user).perform

      counts =
        captured.map do |body|
          content = message_content(body, "user")
          [content.scan(/^P\d+ \|/).size, content.scan(/^I\d+ \|/).size]
        end
      expect(counts).to eq([[25, 40], [40, 80], [60, 120]])
    end

    it "shows currently inked pens to free users" do
      inked_pen = create(:collected_pen, user:, brand: "Sailor", model: "1911")
      create(
        :currently_inked,
        user:,
        collected_pen: inked_pen,
        collected_ink: ink,
        inked_on: 3.days.ago
      )
      stub_pick

      described_class.new(user).perform

      expect(message_content(requests.first, "user")).to include(
        "CURRENTLY INKED (1)\n- Sailor 1911"
      )
    end

    it "never offers a swab or a non-fountain pen" do
      create(:collected_ink, user:, kind: "swab", ink_name: "Swabbed")
      create(:collected_pen, user:, brand: "uni-ball", model: "Signo", nib: "0.38")
      stub_pick

      described_class.new(user).perform

      user_message = message_content(requests.first, "user")
      expect(user_message).not_to include("Swabbed", "Signo")
    end

    it "answers without an LLM call when only non-fountain pens are uninked" do
      pen.update!(nib: "Ballpoint")

      response = described_class.new(user).perform

      expect(response).to eq(message: described_class::NO_UNINKED_PENS_MESSAGE)
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "ends without an LLM call and without counting the run when every pairing was rejected" do
      suggester = described_class.new(user, nil, [{ "pen_id" => pen.id, "ink_id" => ink.id }])

      response = suggester.perform

      expect(response).to eq(
        message: described_class::SELECTION_END_MESSAGES.fetch(:all_pairs_rejected)
      )
      expect(suggester.agent_log.extra_data["precheck"]).to eq("all_pairs_rejected")
      expect(described_class::DailyCap.new(user).send(:today_usage_count)).to eq(0)
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "ends without an LLM call when the only inks are cartridges and no pen takes them" do
      pen.update!(filling_system: "piston")
      ink.update!(kind: "cartridge")

      response = described_class.new(user).perform

      expect(response).to eq(
        message: described_class::SELECTION_END_MESSAGES.fetch(:no_compatible_pairs)
      )
      expect(WebMock).not_to have_requested(:post, openai_url)
    end
  end

  describe "a run with an instruction" do
    let(:instruction) { "Something blue" }

    def legacy_call
      {
        "id" => "call_1",
        "type" => "function",
        "function" => {
          "name" => "record_suggestion",
          "arguments" => { suggestion: "Blue it is.", ink_id: ink.id, pen_id: pen.id }.to_json
        }
      }
    end

    it "keeps today's empty system message, CSV prompt and id-based tool" do
      stub_completions(completion(tool_calls: [legacy_call]))
      srand(42)
      expected_prompt = described_class.new(user, instruction).send(:user_prompt)

      srand(42)
      response = described_class.new(user, instruction).perform

      body = requests.first
      expect(message_content(body, "system")).to eq("")
      expect(message_content(body, "user")).to eq(expected_prompt)
      expect(expected_prompt).to include("pen id,fountain pen name", "Something blue")
      function = body["tools"].sole["function"]
      expect(function["name"]).to eq("record_suggestion")
      expect(function["description"]).to eq(
        "Output for the end user. Must contain a markdown formatted suggestion for a pen and ink " \
          "combination, along with the IDs of the suggested pen and ink."
      )
      expect(function["parameters"]["properties"].keys).to eq(%w[suggestion ink_id pen_id])
      expect(response).to eq(message: "Blue it is.", ink: ink.id, pen: pen.id)
    end

    it "does not log the v2 fields" do
      stub_completions(completion(tool_calls: [legacy_call]))

      suggester = described_class.new(user, instruction)
      suggester.perform

      expect(suggester.agent_log.extra_data.keys).to eq(%w[message ink pen])
    end
  end
end
