require "rails_helper"

RSpec.describe PenAndInkSuggester do
  let(:user) { create(:user) }
  let(:openai_url) { "https://api.openai.com/v1/chat/completions" }

  def record_suggestion_call(id, ink_id:, pen_id:, suggestion: "Suggestion #{id}")
    {
      "id" => id,
      "type" => "function",
      "function" => {
        "name" => "record_suggestion",
        "arguments" => { suggestion:, ink_id:, pen_id: }.to_json
      }
    }
  end

  def completion(tool_calls: nil, content: "")
    message = { "role" => "assistant", "content" => content }
    message["tool_calls"] = tool_calls if tool_calls
    {
      "id" => "chatcmpl-#{SecureRandom.hex(4)}",
      "object" => "chat.completion",
      "created" => 1_677_652_288,
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

  let(:extra_user_input) { "Please suggest something blue" }

  # Create test data
  let!(:collected_pen_1) do
    create(:collected_pen, user: user, brand: "Pilot", model: "Custom 74", nib: "M")
  end

  let!(:collected_pen_2) do
    create(:collected_pen, user: user, brand: "LAMY", model: "Safari", nib: "F")
  end

  let!(:collected_ink_1) do
    ink =
      create(
        :collected_ink,
        user: user,
        brand_name: "Pilot",
        ink_name: "Iroshizuku Kon-peki",
        kind: "bottle"
      )
    # Ensure ink has proper cluster data to avoid nil errors
    macro_cluster = create(:macro_cluster, tags: %w[blue water-based])
    micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
    ink.update!(micro_cluster: micro_cluster)
    ink
  end

  let!(:collected_ink_2) do
    ink =
      create(
        :collected_ink,
        user: user,
        brand_name: "Diamine",
        ink_name: "Blue Velvet",
        kind: "cartridge"
      )
    # Ensure ink has proper cluster data to avoid nil errors
    macro_cluster = create(:macro_cluster, tags: %w[blue cartridge])
    micro_cluster = create(:micro_cluster, macro_cluster: macro_cluster)
    ink.update!(micro_cluster: micro_cluster)
    ink
  end

  let(:successful_openai_response) do
    {
      "id" => "chatcmpl-123",
      "object" => "chat.completion",
      "created" => 1_677_652_288,
      "model" => "gpt-4.1",
      "choices" => [
        {
          "index" => 0,
          "message" => {
            "role" => "assistant",
            "content" => "",
            "tool_calls" => [
              {
                "id" => "call_123",
                "type" => "function",
                "function" => {
                  "name" => "record_suggestion",
                  "arguments" => {
                    "suggestion" =>
                      "**Pilot Custom 74** with **Pilot Iroshizuku Kon-peki** is an excellent combination. The smooth medium nib pairs perfectly with this beautiful blue ink.",
                    "ink_id" => collected_ink_1.id,
                    "pen_id" => collected_pen_1.id
                  }.to_json
                }
              }
            ]
          },
          "finish_reason" => "tool_calls"
        }
      ],
      "usage" => {
        "prompt_tokens" => 150,
        "completion_tokens" => 50,
        "total_tokens" => 200
      }
    }
  end

  subject { described_class.new(user, extra_user_input) }

  describe "#initialize" do
    it "creates agent with user and preferences" do
      suggester = described_class.new(user, extra_user_input)
      expect(suggester.agent_log.owner).to eq(user)
      expect(suggester.agent_log.name).to eq("PenAndInkSuggester")
      expect(suggester.agent_log).to be_persisted
    end

    it "works without extra user input" do
      suggester = described_class.new(user, nil)
      expect(suggester.agent_log.owner).to eq(user)
    end
  end

  describe "rejected suggestions in the user prompt" do
    it "embeds the validated {ink_id, pen_id} pairs as JSON" do
      pairs = [{ ink_id: 1, pen_id: 2 }, { ink_id: 3, pen_id: 4 }]
      suggester = described_class.new(user, nil, pairs)
      prompt = suggester.send(:user_prompt)

      expect(prompt).to include('"ink_id":1')
      expect(prompt).to include('"pen_id":4')
      expect(prompt).to include("rejected. Do not recommend them again")
    end

    it "does not include the section when no pairs are passed" do
      suggester = described_class.new(user, nil, [])
      prompt = suggester.send(:user_prompt)
      expect(prompt).not_to include("rejected")
    end
  end

  describe "#agent_log" do
    it "creates and memoizes agent log" do
      log1 = subject.agent_log
      log2 = subject.agent_log

      expect(log1).to be_persisted
      expect(log1.name).to eq("PenAndInkSuggester")
      expect(log1.owner).to eq(user)
      expect(log1).to eq(log2)
    end
  end

  describe "#perform" do
    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "returns successful response with suggestion" do
      response = subject.perform

      expect(response[:message]).to include("Pilot Custom 74")
      expect(response[:message]).to include("Pilot Iroshizuku Kon-peki")
      expect(response[:ink]).to eq(collected_ink_1.id)
      expect(response[:pen]).to eq(collected_pen_1.id)
    end

    it "updates agent log appropriately" do
      response = subject.perform

      expect(subject.agent_log.extra_data).to eq(response.stringify_keys)
      expect(subject.agent_log.state).to eq("waiting-for-approval")
    end

    it "makes HTTP request to OpenAI API" do
      subject.perform

      expect(WebMock).to have_requested(
        :post,
        "https://api.openai.com/v1/chat/completions"
      ).at_least_once
    end

    it "sends pen and ink data to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

          expect(content).to include("Given the following fountain pens:")
          expect(content).to include("Given the following inks:")
          expect(content).to include(collected_pen_1.brand)
          expect(content).to include(collected_ink_1.ink_name)

          true
        }
        .at_least_once
    end

    it "includes function definition for record_suggestion" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          body["tools"]&.present? && body["tools"].first["function"]["name"] == "record_suggestion"
        }
        .at_least_once
    end

    context "with extra user input" do
      it "includes extra user instructions in user message" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
            expect(content).to include("Please suggest something blue")
            true
          }
          .at_least_once
      end
    end

    context "includes all ink types" do
      it "includes both bottle and cartridge inks" do
        subject.perform

        expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
          .with { |req|
            body = JSON.parse(req.body)
            content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
            expect(content).to include(collected_ink_1.ink_name) # bottle
            expect(content).to include(collected_ink_2.ink_name) # cartridge
            true
          }
          .at_least_once
      end
    end
  end

  describe "data formatting" do
    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "sends CSV formatted data to OpenAI" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

          # Should contain CSV headers
          expect(content).to include("pen id,fountain pen name")
          expect(content).to include("ink id,ink name")

          # Should contain usage tracking columns
          expect(content).to include("usage count,daily usage count")
          expect(content).to include("last usage")

          # Should contain actual data
          expect(content).to include(collected_pen_1.id.to_s)
          expect(content).to include(collected_ink_1.id.to_s)

          true
        }
        .at_least_once
    end

    it "includes pen and ink details for AI context" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")

          expect(content).to include("Pilot")
          expect(content).to include("Custom 74")
          expect(content).to include("Iroshizuku Kon-peki")

          true
        }
        .at_least_once
    end

    it "handles special characters in names" do
      create(:collected_pen, user: user, brand: 'Test "Brand"', model: 'Model "Special"')

      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
          expect(content).to include("Brand")
          expect(content).to include("Special")
          true
        }
        .at_least_once
    end
  end

  describe "request options" do
    before do
      stub_request(:post, openai_url).to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "disables parallel tool calls and requires a tool call" do
      subject.perform

      expect(WebMock).to have_requested(:post, openai_url).with { |req|
        body = JSON.parse(req.body)
        body["parallel_tool_calls"] == false && body["tool_choice"] == "required"
      }
    end

    it "uses the mini model for free users" do
      subject.perform

      expect(WebMock).to have_requested(:post, openai_url).with(
        body: hash_including("model" => "gpt-4.1-mini")
      )
    end

    it "uses the full model for patrons" do
      user.update!(patron: true)

      subject.perform

      expect(WebMock).to have_requested(:post, openai_url).with(
        body: hash_including("model" => "gpt-4.1")
      )
    end

    it "uses the full model for admins" do
      user.update!(admin: true)

      subject.perform

      expect(WebMock).to have_requested(:post, openai_url).with(
        body: hash_including("model" => "gpt-4.1")
      )
    end
  end

  describe "precheck" do
    def ink_pen(pen)
      create(:currently_inked, user:, collected_pen: pen, collected_ink: collected_ink_1)
    end

    it "answers without an LLM call when every pen is inked" do
      ink_pen(collected_pen_1)
      ink_pen(collected_pen_2)

      response = subject.perform

      expect(response).to eq({ message: described_class::NO_UNINKED_PENS_MESSAGE })
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "answers without an LLM call when there are no active pens" do
      collected_pen_1.archive!
      collected_pen_2.destroy!

      response = subject.perform

      expect(response).to eq({ message: described_class::NO_UNINKED_PENS_MESSAGE })
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "stops on all pens being inked even with an instruction" do
      ink_pen(collected_pen_1)
      ink_pen(collected_pen_2)

      response = described_class.new(user, "Use my Pilot Custom 74").perform

      expect(response[:message]).to eq(described_class::NO_UNINKED_PENS_MESSAGE)
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "answers without an LLM call when the only inks are swabs" do
      collected_ink_1.update!(kind: "swab")
      collected_ink_2.update!(kind: "swab")

      response = subject.perform

      expect(response).to eq({ message: described_class::NO_FILLABLE_INKS_MESSAGE })
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "answers without an LLM call when there are no active inks" do
      collected_ink_1.archive!
      collected_ink_2.archive!

      response = subject.perform

      expect(response).to eq({ message: described_class::NO_FILLABLE_INKS_MESSAGE })
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "treats an ink without a kind as fillable" do
      collected_ink_1.update!(kind: "swab")
      collected_ink_2.update!(kind: nil)
      stub_completions(
        completion(
          tool_calls: [
            record_suggestion_call("call_1", ink_id: collected_ink_2.id, pen_id: collected_pen_1.id)
          ]
        )
      )

      response = subject.perform

      expect(response[:ink]).to eq(collected_ink_2.id)
    end

    it "marks the agent log with the precheck reason" do
      collected_ink_1.update!(kind: "swab")
      collected_ink_2.update!(kind: "swab")

      subject.perform

      expect(subject.agent_log.extra_data).to eq(
        { "message" => described_class::NO_FILLABLE_INKS_MESSAGE, "precheck" => "no_fillable_inks" }
      )
      expect(subject.agent_log.state).to eq("waiting-for-approval")
    end

    it "does not count precheck runs toward the daily cap" do
      collected_ink_1.update!(kind: "swab")
      collected_ink_2.update!(kind: "swab")
      described_class::MAX_PER_DAY.times { described_class.new(user).perform }
      collected_ink_1.update!(kind: "bottle")
      stub_request(:post, openai_url).to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )

      response = subject.perform

      expect(response[:ink]).to eq(collected_ink_1.id)
      expect(WebMock).to have_requested(:post, openai_url).once
    end
  end

  describe "daily cap" do
    before do
      stub_request(:post, openai_url).to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    def create_logs(count, created_at: Time.current)
      create_list(:agent_log, count, name: "PenAndInkSuggester", owner: user, created_at:)
    end

    it "allows the 20th run of the day for free users" do
      create_logs(19)

      subject.perform

      expect(WebMock).to have_requested(:post, openai_url).once
    end

    it "stops free users after 20 runs a day" do
      create_logs(20)

      response = subject.perform

      expect(response[:message]).to include("daily limit of 20 suggestions")
      expect(response[:message]).to include("Patron")
      expect(WebMock).not_to have_requested(:post, openai_url)
    end

    it "ignores runs from previous days" do
      create_logs(20, created_at: 1.day.ago.beginning_of_day)

      subject.perform

      expect(WebMock).to have_requested(:post, openai_url).once
    end

    it "ignores other agents' logs" do
      create_list(:agent_log, 20, name: "SpamClassifier", owner: user)

      subject.perform

      expect(WebMock).to have_requested(:post, openai_url).once
    end

    it "allows the 50th run of the day for patrons" do
      user.update!(patron: true)
      create_logs(49)

      subject.perform

      expect(WebMock).to have_requested(:post, openai_url).once
    end

    it "stops patrons after 50 runs a day" do
      user.update!(patron: true)
      create_logs(50)

      response = subject.perform

      expect(response[:message]).to eq(
        "You have reached your daily limit of 50 suggestions. Please try again tomorrow."
      )
      expect(WebMock).not_to have_requested(:post, openai_url)
    end
  end

  describe "agent log per request" do
    before do
      stub_request(:post, openai_url).to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "does not reuse a stale processing log" do
      stale =
        create(
          :agent_log,
          name: "PenAndInkSuggester",
          owner: user,
          state: AgentLog::PROCESSING,
          transcript: [{ "role" => "user", "content" => "Stale prompt from an earlier run" }]
        )

      subject.perform

      expect(subject.agent_log).not_to eq(stale)
      expect(stale.reload.state).to eq(AgentLog::PROCESSING)
      expect(WebMock).not_to have_requested(:post, openai_url).with(
        body: /Stale prompt from an earlier run/
      )
    end

    it "creates a new log for every run" do
      expect {
        described_class.new(user).perform
        described_class.new(user).perform
      }.to change { user.agent_logs.where(name: "PenAndInkSuggester").count }.by(2)
    end
  end

  describe "multiple tool calls" do
    it "returns the first valid suggestion from a parallel response" do
      stub_completions(
        completion(
          tool_calls: [
            record_suggestion_call("call_1", ink_id: 99_999, pen_id: collected_pen_1.id),
            record_suggestion_call(
              "call_2",
              ink_id: collected_ink_1.id,
              pen_id: collected_pen_1.id,
              suggestion: "First valid"
            ),
            record_suggestion_call(
              "call_3",
              ink_id: collected_ink_2.id,
              pen_id: collected_pen_2.id,
              suggestion: "Second valid"
            ),
            record_suggestion_call("call_4", ink_id: collected_ink_1.id, pen_id: 99_999),
            record_suggestion_call(
              "call_5",
              ink_id: collected_ink_2.id,
              pen_id: collected_pen_1.id,
              suggestion: "Third valid"
            )
          ]
        )
      )

      response = subject.perform

      expect(response).to eq(
        { message: "First valid", ink: collected_ink_1.id, pen: collected_pen_1.id }
      )
      expect(WebMock).to have_requested(:post, openai_url).once
    end

    it "retries after an invalid call" do
      stub_completions(
        completion(
          tool_calls: [record_suggestion_call("call_1", ink_id: 99_999, pen_id: collected_pen_1.id)]
        ),
        completion(
          tool_calls: [
            record_suggestion_call(
              "call_2",
              ink_id: collected_ink_2.id,
              pen_id: collected_pen_2.id,
              suggestion: "Valid"
            )
          ]
        )
      )

      response = subject.perform

      expect(response).to eq({ message: "Valid", ink: collected_ink_2.id, pen: collected_pen_2.id })
      expect(WebMock).to have_requested(:post, openai_url).twice
    end
  end

  describe "handled failures" do
    it "returns the error message when no decision is reached" do
      stub_completions(completion(content: "I suggest the Pilot."))

      response = subject.perform

      expect(response).to eq({ message: described_class::ERROR_MESSAGE })
      expect(subject.agent_log.extra_data).to eq(
        { "message" => described_class::ERROR_MESSAGE, "error" => "DecisionNotReachedError" }
      )
      expect(subject.agent_log.state).to eq("waiting-for-approval")
    end

    it "returns the error message when the tool-call limit is exceeded without a result" do
      stub_completions(
        completion(
          tool_calls:
            13.times.map do |i|
              record_suggestion_call("call_#{i}", ink_id: 99_999, pen_id: collected_pen_1.id)
            end
        )
      )

      response = subject.perform

      expect(response).to eq({ message: described_class::ERROR_MESSAGE })
      expect(subject.agent_log.extra_data["error"]).to eq("ToolCallLimitExceeded")
      expect(WebMock).to have_requested(:post, openai_url).once
    end

    it "allows 12 tool calls" do
      stub_completions(
        completion(
          tool_calls:
            11.times.map do |i|
              record_suggestion_call("call_#{i}", ink_id: 99_999, pen_id: collected_pen_1.id)
            end +
              [
                record_suggestion_call(
                  "call_11",
                  ink_id: collected_ink_1.id,
                  pen_id: collected_pen_1.id,
                  suggestion: "Twelfth"
                )
              ]
        )
      )

      response = subject.perform

      expect(response).to eq(
        { message: "Twelfth", ink: collected_ink_1.id, pen: collected_pen_1.id }
      )
      expect(subject.agent_log.extra_data).not_to have_key("error")
    end

    it "returns the recorded suggestion when the limit is exceeded after a valid call" do
      stub_completions(
        completion(
          tool_calls:
            [
              record_suggestion_call(
                "call_0",
                ink_id: collected_ink_1.id,
                pen_id: collected_pen_1.id,
                suggestion: "Recorded"
              )
            ] +
              12.times.map do |i|
                record_suggestion_call("call_#{i + 1}", ink_id: 99_999, pen_id: 99_999)
              end
        )
      )

      response = subject.perform

      expect(response).to eq(
        { message: "Recorded", ink: collected_ink_1.id, pen: collected_pen_1.id }
      )
      expect(subject.agent_log.extra_data["error"]).to eq("ToolCallLimitExceeded")
    end
  end

  describe "error handling" do
    context "when OpenAI API returns 500 error" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 500,
          body: { error: { message: "Internal server error" } }.to_json,
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises an error" do
        expect { subject.perform }.to raise_error(RubyLLM::ServerError)
      end
    end

    context "when OpenAI returns malformed JSON" do
      before(:each) do
        stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
          status: 200,
          body: "invalid json",
          headers: {
            "Content-Type" => "application/json"
          }
        )
      end

      it "raises a parsing error" do
        expect { subject.perform }.to raise_error(Faraday::ParsingError)
      end
    end
  end

  describe "tools" do
    describe PenAndInkSuggester::RecordSuggestion do
      let(:inks) { user.collected_inks.active }
      let(:pens) { user.collected_pens.active }

      it "has the correct name" do
        tool = described_class.new(inks, pens)
        expect(tool.name).to eq("record_suggestion")
      end

      it "records suggestion and halts on valid input" do
        tool = described_class.new(inks, pens)
        result =
          tool.call(
            suggestion: "Great combination!",
            ink_id: collected_ink_1.id,
            pen_id: collected_pen_1.id
          )

        expect(result).to be_a(RubyLLM::Tool::Halt)
        expect(tool.message).to eq("Great combination!")
        expect(tool.result_ink_id).to eq(collected_ink_1.id)
        expect(tool.result_pen_id).to eq(collected_pen_1.id)
      end

      it "returns error for invalid ink ID" do
        tool = described_class.new(inks, pens)
        result = tool.call(suggestion: "Test", ink_id: 99_999, pen_id: collected_pen_1.id)

        expect(result).to eq("Please try again. The ink ID is invalid.")
      end

      it "returns error for invalid pen ID" do
        tool = described_class.new(inks, pens)
        result = tool.call(suggestion: "Test", ink_id: collected_ink_1.id, pen_id: 99_999)

        expect(result).to eq("Please try again. The pen ID is invalid.")
      end

      it "returns error for both invalid IDs" do
        tool = described_class.new(inks, pens)
        result = tool.call(suggestion: "Test", ink_id: 99_999, pen_id: 99_999)

        expect(result).to eq("Please try again. Both the pen and ink IDs are invalid.")
      end

      it "returns error for blank suggestion" do
        tool = described_class.new(inks, pens)
        result = tool.call(suggestion: "", ink_id: collected_ink_1.id, pen_id: collected_pen_1.id)

        expect(result).to eq("Please try again. The suggestion message is blank.")
      end

      it "keeps the first valid suggestion when called again" do
        tool = described_class.new(inks, pens)
        tool.call(suggestion: "First", ink_id: collected_ink_1.id, pen_id: collected_pen_1.id)
        result =
          tool.call(suggestion: "Second", ink_id: collected_ink_2.id, pen_id: collected_pen_2.id)

        expect(result).to be_a(RubyLLM::Tool::Halt)
        expect(result.content).to eq("Suggestion already recorded")
        expect(tool.result).to eq(
          { message: "First", ink: collected_ink_1.id, pen: collected_pen_1.id }
        )
      end

      it "ignores an invalid call after a valid one" do
        tool = described_class.new(inks, pens)
        tool.call(suggestion: "First", ink_id: collected_ink_1.id, pen_id: collected_pen_1.id)
        result = tool.call(suggestion: "Second", ink_id: 99_999, pen_id: 99_999)

        expect(result.content).to eq("Suggestion already recorded")
        expect(tool.result[:message]).to eq("First")
      end

      it "has no result before a valid call" do
        tool = described_class.new(inks, pens)
        tool.call(suggestion: "Test", ink_id: 99_999, pen_id: collected_pen_1.id)

        expect(tool.result).to be_nil
      end
    end
  end

  describe "integration test" do
    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "completes full suggestion workflow" do
      response = subject.perform

      expect(response[:message]).to include("Pilot Custom 74")
      expect(response[:message]).to include("Pilot Iroshizuku Kon-peki")
      expect(response[:ink]).to eq(collected_ink_1.id)
      expect(response[:pen]).to eq(collected_pen_1.id)
      expect(subject.agent_log.state).to eq("waiting-for-approval")
    end

    it "includes clustering data for AI context" do
      subject.perform

      expect(WebMock).to have_requested(:post, "https://api.openai.com/v1/chat/completions")
        .with { |req|
          body = JSON.parse(req.body)
          content = body["messages"].find { |m| m["role"] == "user" }&.[]("content")
          # Should include columns for clustering information
          expect(content).to include("tags,description")
          true
        }
        .at_least_once
    end
  end

  describe "transcript and usage tracking" do
    before(:each) do
      stub_request(:post, "https://api.openai.com/v1/chat/completions").to_return(
        status: 200,
        body: successful_openai_response.to_json,
        headers: {
          "Content-Type" => "application/json"
        }
      )
    end

    it "updates agent log transcript" do
      subject.perform

      transcript = subject.agent_log.transcript
      expect(transcript).to be_an(Array)
      expect(transcript.length).to be >= 3
      expect(transcript.any? { |e| e["role"] == "user" }).to be true
      expect(transcript.any? { |e| e["role"] == "assistant" }).to be true
    end

    it "updates agent log usage" do
      subject.perform

      usage = subject.agent_log.usage
      expect(usage["prompt_tokens"]).to eq(150)
      expect(usage["completion_tokens"]).to eq(50)
      expect(usage["total_tokens"]).to eq(200)
      expect(usage["model"]).to eq("gpt-4.1")
    end
  end
end
