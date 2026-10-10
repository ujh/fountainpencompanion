require "rails_helper"

RSpec.describe PenAndInkSuggester do
  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }
  let(:user) { create(:user, confirmed_at: 1.month.ago) }
  let!(:lamy) do
    create(:collected_pen, user:, brand: "Lamy", model: "2000", color: "Black", nib: "B")
  end
  let!(:safari) do
    create(:collected_pen, user:, brand: "Lamy", model: "Safari", color: "Yellow", nib: "F")
  end
  let!(:oxblood) do
    create(:collected_ink, user:, brand_name: "Diamine", ink_name: "Oxblood", kind: "bottle")
  end
  let!(:kon_peki) do
    create(
      :collected_ink,
      user:,
      brand_name: "Pilot",
      line_name: "Iroshizuku",
      ink_name: "Kon-peki",
      kind: "bottle"
    )
  end

  def record_call(id = "call_1", pen_ref: "P1", ink_ref: "I1", reasoning: "A fine pairing.")
    {
      "id" => id,
      "type" => "function",
      "function" => {
        "name" => "record_suggestion",
        "arguments" => { pen_ref:, ink_ref:, reasoning: }.to_json
      }
    }
  end

  def completion(tool_calls: nil)
    message = { "role" => "assistant", "content" => "" }
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

  def user_message
    message_content(requests.first, "user")
  end

  def ink_pen(pen, ink = oxblood)
    create(:currently_inked, user:, collected_pen: pen, collected_ink: ink, inked_on: 3.days.ago)
  end

  def counted_runs
    described_class::DailyCap.new(user).send(:today_usage_count)
  end

  describe "an instruction that names nothing" do
    it "sends the static rules, unfiltered lists and the request" do
      stub_pick

      described_class.new(user, "Something red").perform

      body = requests.first
      expect(message_content(body, "system")).to eq(
        PenAndInkSuggestion::PickPrompt::SYSTEM_DIRECTIVE
      )
      expect(user_message).to include(
        "PENS UNFILTERED (2 of 2 uninked)",
        "INKS UNFILTERED (2 of 2)"
      )
      expect(user_message).to end_with("<request>Something red</request>")
      expect(body["tools"].sole["function"]["parameters"]["properties"].keys).to eq(
        %w[pen_ref pen_name ink_ref ink_name reasoning]
      )
    end

    it "sends today's tier limits per side: 50 for free users, 100 for patrons, 200 for admins" do
      create_list(:collected_pen, 199, user:)
      create_list(:collected_ink, 199, user:)
      captured = []
      stub_request(:post, openai_url).to_return do |request|
        captured << JSON.parse(request.body)
        {
          status: 200,
          body: completion(tool_calls: [record_call]).to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        }
      end

      described_class.new(user, "Something red").perform
      user.update!(patron: true)
      described_class.new(user, "Something red").perform
      user.update!(admin: true)
      described_class.new(user, "Something red").perform

      counts =
        captured.map do |body|
          content = message_content(body, "user")
          [content.scan(/^P\d+ \|/).size, content.scan(/^I\d+ \|/).size]
        end
      expect(counts).to eq([[50, 50], [100, 100], [200, 200]])
    end

    it "logs the fallback source without pins" do
      stub_pick

      suggester = described_class.new(user, "Black ink")
      suggester.perform

      expect(suggester.agent_log.extra_data).to include(
        "constraints" => nil,
        "constraints_source" => "fallback",
        "mentions" => [],
        "pins" => [],
        "notes" => []
      )
    end
  end

  describe "an instruction that names a pen" do
    it "sends only the named pen and marks it" do
      stub_pick

      described_class.new(user, "an ink for my Lamy 2000 please").perform

      expect(user_message).to include("PENS (★ requested)\nP1 ★ | Lamy 2000, Black")
      expect(user_message).not_to include("Safari")
      expect(user_message).to include("INKS UNFILTERED (2 of 2)")
    end

    it "logs the mention and the pin" do
      stub_pick

      suggester = described_class.new(user, "an ink for my Lamy 2000 please")
      response = suggester.perform

      expect(response[:pen]).to eq(lamy.id)
      expect(suggester.agent_log.extra_data).to include(
        "mentions" => [{ "text" => "Lamy 2000", "side" => "pen" }],
        "pins" => [{ "pen_id" => lamy.id }]
      )
    end

    it "cannot record a pen other than the pinned one" do
      stub_completions(
        completion(tool_calls: [record_call("call_1", pen_ref: "P2")]),
        completion(tool_calls: [record_call("call_2")])
      )

      response = described_class.new(user, "Lamy 2000").perform

      expect(response[:pen]).to eq(lamy.id)
      tool_message = requests.last["messages"].find { |message| message["role"] == "tool" }
      expect(tool_message["content"]).to eq("P2 is not valid for pen_ref; use a P ref from PENS.")
    end

    it "suggests a named pen that is currently inked, with the note and the flag" do
      inking = ink_pen(lamy, kon_peki)
      stub_pick

      suggester = described_class.new(user, "Lamy 2000")
      response = suggester.perform

      expect(response).to include(
        pen: lamy.id,
        pen_currently_inked: true,
        currently_inked_id: inking.id
      )
      expect(response[:message]).to include(
        "_Currently inked with Pilot Iroshizuku Kon-peki — empty and clean it first._"
      )
      expect(user_message).to include("currently inked with Pilot Iroshizuku Kon-peki")
    end

    it "suggests a named inked pen when every pen is inked" do
      ink_pen(lamy)
      ink_pen(safari)
      stub_pick

      response = described_class.new(user, "Lamy 2000").perform

      expect(response).to include(pen: lamy.id, pen_currently_inked: true)
    end

    it "says so when the named pen is not in the collection and goes with the closest" do
      create(:collected_pen, user:, brand: "Asvine", model: "V126")
      stub_pick

      suggester = described_class.new(user, "ink for my Asvine V-128")
      response = suggester.perform

      note =
        "I couldn't find \"Asvine V-128\" in your collection, so I went with the closest: " \
          "Asvine V126."
      expect(response[:message]).to include("_#{note}_")
      expect(user_message).to include("SERVER NOTES (already shown): #{note}")
      expect(suggester.agent_log.extra_data["notes"]).to eq([note])
    end
  end

  describe "an instruction that names an ink" do
    it "sends only the named ink and keeps the pens unfiltered" do
      stub_pick

      described_class.new(user, "a pen for Pilot Kon-peki").perform

      expect(user_message).to include("INKS (★ requested)\nI1 ★ | Pilot Iroshizuku Kon-peki")
      expect(user_message).not_to include("Oxblood")
      expect(user_message).to include("PENS UNFILTERED (2 of 2 uninked)")
    end

    it "ends without a pick when the named cartridge ink fits no pen" do
      lamy.update!(filling_system: "piston")
      safari.update!(filling_system: "piston")
      kon_peki.update!(kind: "cartridge")

      response = described_class.new(user, "a pen for Pilot Kon-peki").perform

      expect(response).to eq(
        message: described_class::PINNED_END_MESSAGES.fetch(:no_compatible_pairs)
      )
      expect(WebMock).not_to have_requested(:post, openai_url)
    end
  end

  describe "when every pen is inked" do
    before do
      ink_pen(lamy)
      ink_pen(safari)
    end

    it "ends without an LLM call when the instruction names no pen" do
      suggester = described_class.new(user, "Something with Diamine Oxblood")

      response = suggester.perform

      expect(response).to eq(message: described_class::NAME_INKED_PEN_MESSAGE)
      expect(suggester.agent_log.extra_data).to include(
        "precheck" => "no_uninked_or_named_pens",
        "pins" => [{ "ink_id" => oxblood.id }]
      )
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "does not count that run toward the daily cap, since no LLM call was made" do
      described_class.new(user, "a Visconti please").perform

      expect(counted_runs).to eq(0)
    end

    it "asks to name a pen when the user may write instructions" do
      create_list(:collected_ink, 20, user:)

      response = described_class.new(user).perform

      expect(response).to eq(message: described_class::NAME_INKED_PEN_MESSAGE)
    end

    it "only asks to clean a pen when the user may not write instructions yet" do
      response = described_class.new(user).perform

      expect(response).to eq(message: described_class::NO_UNINKED_PENS_MESSAGE)
    end
  end
end
